import Combine
import Foundation

enum ABXSlot {
    case a
    case b
    case x
}

@MainActor
final class CodecLabViewModel: ObservableObject {
    @Published var referenceInfo: AudioFileInfo?
    @Published var legacyInfo: AudioFileInfo?
    @Published var region = TestRegion.defaultRegion
    @Published var diagnostics = EncoderDiagnostics.unavailable
    @Published var currentArtifacts: CurrentMP3Artifacts?
    @Published var legacyArtifacts: LegacyMP3Artifacts?
    @Published var nullTestResult: NullTestResult?
    @Published var selectedBitrateKbps = 320
    @Published var monitorMode: MonitorMode = .nativeMultichannel
    @Published var statusMessage = "Ready"
    @Published var isBusy = false

    let playbackEngine = AudioPlaybackEngine()
    let abxService = ABXService()

    private let audioImportService = AudioImportService()
    private let availabilityService = EncoderAvailabilityService()
    private let encoderService = EncoderService()
    private let legacyImportService = LegacyMP3ImportService()
    private let nullTestService = NullTestService()

    init() {
        Task {
            await refreshDiagnostics()
        }
    }

    func refreshDiagnostics() async {
        diagnostics = await availabilityService.diagnostics()
    }

    func importReference(url: URL) async {
        await performBusyOperation("Reading reference metadata...") { [self] in
            let info = try await self.audioImportService.readInfo(from: url)
            self.referenceInfo = info
            self.currentArtifacts = nil
            self.nullTestResult = nil
            self.playbackEngine.setBuffer(PlaybackBuffer(source: .original, url: url, displayName: info.fileName))
            self.statusMessage = "Reference loaded: \(info.fileName)"
        }
    }

    func importLegacyMP3(url: URL) async {
        await performBusyOperation("Decoding legacy MP3...") { [self] in
            let info = try await self.audioImportService.readInfo(from: url)
            let artifacts = try await self.legacyImportService.decodeLegacyMP3(url, diagnostics: self.diagnostics)
            self.legacyInfo = info
            self.legacyArtifacts = artifacts
            self.playbackEngine.setBuffer(PlaybackBuffer(source: .legacyMP3, url: artifacts.decodedWAVURL, displayName: info.fileName))
            self.statusMessage = "Legacy MP3 decoded: \(info.fileName)"
        }
    }

    func generateCurrentMP3() async {
        guard let referenceInfo else {
            statusMessage = "Load a reference audio file first."
            return
        }

        await performBusyOperation("Generating Current MP3...") { [self] in
            let artifacts = try await self.encoderService.generateCurrentMP3(
                referenceURL: referenceInfo.url,
                region: self.boundedRegion(for: referenceInfo),
                diagnostics: self.diagnostics,
                bitrateKbps: self.selectedBitrateKbps
            )
            self.currentArtifacts = artifacts
            self.playbackEngine.setBuffers([
                PlaybackBuffer(source: .original, url: artifacts.originalSegmentURL, displayName: "Original Segment"),
                PlaybackBuffer(source: .currentMP3, url: artifacts.decodedWAVURL, displayName: "Current MP3 \(self.selectedBitrateKbps)k")
            ])
            self.statusMessage = "Current MP3 \(self.selectedBitrateKbps)k generated."
        }
    }

    func runNullTestForCurrentMP3() {
        guard let currentArtifacts else {
            statusMessage = "Generate Current MP3 before running Null Test."
            return
        }

        do {
            nullTestResult = try nullTestService.analyze(
                originalURL: currentArtifacts.originalSegmentURL,
                decodedURL: currentArtifacts.decodedWAVURL
            )
            statusMessage = "Null Test complete."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func play(_ source: MonitorSource) {
        do {
            try playbackEngine.play(source)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func stopPlayback() {
        playbackEngine.stop()
    }

    func startABX(totalTrials: Int = 10) {
        guard currentArtifacts != nil else {
            statusMessage = "Generate Current MP3 before starting ABX."
            return
        }
        abxService.start(totalTrials: totalTrials)
        statusMessage = "ABX started."
    }

    func playABXSlot(_ slot: ABXSlot) {
        guard let session = abxService.session,
              let trial = session.trials[safe: session.currentIndex] else { return }

        let identity: ABXIdentity
        switch slot {
        case .a:
            identity = trial.a
        case .b:
            identity = trial.b
        case .x:
            identity = trial.x
        }

        play(identity == .original ? .original : .currentMP3)
    }

    func submitABXGuess(_ identity: ABXIdentity) {
        abxService.submitGuess(identity)
        if let session = abxService.session {
            let p = ABXService.pValue(correct: session.correctCount, total: max(session.completedCount, 1))
            statusMessage = "ABX \(session.correctCount)/\(session.completedCount), p=\(String(format: "%.4f", p))"
        }
    }

    func boundedRegion(for info: AudioFileInfo) -> TestRegion {
        guard info.duration > 0 else { return region }
        let duration = min(region.duration, info.duration)
        let start = min(region.startTime, max(0, info.duration - duration))
        return TestRegion(startTime: start, duration: duration)
    }

    private func performBusyOperation(_ message: String, operation: @escaping () async throws -> Void) async {
        isBusy = true
        statusMessage = message
        defer { isBusy = false }

        do {
            try await operation()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
