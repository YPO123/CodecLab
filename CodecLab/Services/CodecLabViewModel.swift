import Combine
import Foundation

enum ABXSlot {
    case a
    case b
    case x
}

enum ExportPackageItem: String, CaseIterable, Identifiable, Hashable {
    case encodedMonitor
    case differenceWAV
    case htmlReport
    case jsonReport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .encodedMonitor: return "Encoded Monitor"
        case .differenceWAV: return "Difference WAV"
        case .htmlReport: return "HTML Report"
        case .jsonReport: return "JSON Report"
        }
    }

    var detail: String {
        switch self {
        case .encodedMonitor: return "Current lossy file"
        case .differenceWAV: return "Residual audio after Null Test"
        case .htmlReport: return "Readable listening report"
        case .jsonReport: return "Structured test data"
        }
    }

    var systemImage: String {
        switch self {
        case .encodedMonitor: return "waveform.path.ecg"
        case .differenceWAV: return "plus.forwardslash.minus"
        case .htmlReport: return "doc.richtext"
        case .jsonReport: return "curlybraces.square"
        }
    }

    var badge: String {
        switch self {
        case .encodedMonitor: return "AUDIO"
        case .differenceWAV: return "WAV"
        case .htmlReport: return "HTML"
        case .jsonReport: return "JSON"
        }
    }
}

enum ExportPackageError: LocalizedError {
    case noReadyItems
    case missingReport

    var errorDescription: String? {
        switch self {
        case .noReadyItems:
            return "Nothing is ready to export yet."
        case .missingReport:
            return "Load a reference file before exporting a report."
        }
    }
}

@MainActor
final class CodecLabViewModel: ObservableObject {
    @Published var referenceInfo: AudioFileInfo?
    @Published var legacyInfo: AudioFileInfo?
    @Published var region = TestRegion.defaultRegion
    @Published var diagnostics = EncoderDiagnostics.unavailable
    @Published var currentArtifacts: CurrentMP3Artifacts?
    @Published var renderedArtifacts: RenderedCodecArtifacts?
    @Published var legacyArtifacts: LegacyMP3Artifacts?
    @Published var nullTestResult: NullTestResult?
    @Published var selectedCodec: CodecRailFormat = .mp3
    @Published var selectedBitrateKbps: Double = 320
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
    private let reportExportService = ReportExportService()

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
            self.renderedArtifacts = nil
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
        selectCodec(.mp3)
        await renderSelectedLossyMonitor()
    }

    func selectCodec(_ codec: CodecRailFormat) {
        guard selectedCodec != codec else { return }
        selectedCodec = codec
        invalidateRenderedMonitor()
    }

    func selectBitrateKbps(_ bitrate: Int) {
        guard roundedBitrateKbps != bitrate else { return }
        selectedBitrateKbps = Double(bitrate)
        invalidateRenderedMonitor()
    }

    func renderSelectedLossyMonitor() async {
        guard let referenceInfo else {
            statusMessage = "Load a reference audio file first."
            return
        }

        guard let format = selectedCodec.codecFormat else {
            statusMessage = "Import a legacy MP3 for the Legacy slot."
            return
        }

        let bitrate = roundedBitrateKbps
        let settings = EncodeSettings(
            format: format,
            encoder: selectedCodec.encoderType,
            bitrateKbps: bitrate,
            sampleRate: nil,
            channels: nil,
            downmixMode: nil
        )

        await performBusyOperation("Rendering \(selectedCodec.label) \(bitrate)k monitor...") { [self] in
            let artifacts = try await self.encoderService.renderCodec(
                referenceURL: referenceInfo.url,
                region: self.boundedRegion(for: referenceInfo),
                diagnostics: self.diagnostics,
                settings: settings
            )
            self.renderedArtifacts = artifacts
            if settings.format == .mp3 {
                self.currentArtifacts = CurrentMP3Artifacts(
                    workingDirectory: artifacts.workingDirectory,
                    originalSegmentURL: artifacts.originalSegmentURL,
                    encodedMP3URL: artifacts.encodedURL,
                    decodedWAVURL: artifacts.decodedWAVURL,
                    bitrateKbps: bitrate
                )
            } else {
                self.currentArtifacts = nil
            }
            self.playbackEngine.setBuffers([
                PlaybackBuffer(source: .original, url: artifacts.originalSegmentURL, displayName: "Original Segment"),
                PlaybackBuffer(source: .currentMP3, url: artifacts.decodedWAVURL, displayName: "\(self.selectedCodec.label) \(bitrate)k")
            ])
            self.statusMessage = "\(self.selectedCodec.label) \(bitrate)k monitor ready."
        }
    }

    func runNullTestForCurrentMP3() {
        runNullTestForRenderedCodec()
    }

    func runNullTestForRenderedCodec() {
        guard let renderedArtifacts else {
            statusMessage = "Render a lossy monitor before running Null Test."
            return
        }

        do {
            let result = try nullTestService.analyze(
                originalURL: renderedArtifacts.originalSegmentURL,
                decodedURL: renderedArtifacts.decodedWAVURL,
                differenceOutputURL: renderedArtifacts.workingDirectory.appendingPathComponent("CodecLab Difference.wav")
            )
            nullTestResult = result
            if let differenceFileURL = result.differenceFileURL {
                playbackEngine.setBuffer(PlaybackBuffer(source: .difference, url: differenceFileURL, displayName: "Difference WAV"))
            }
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
        guard renderedArtifacts != nil else {
            statusMessage = "Render a lossy monitor before starting ABX."
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

    var roundedBitrateKbps: Int {
        Int((selectedBitrateKbps / 8).rounded() * 8)
    }

    var lossyMonitorLabel: String {
        if selectedCodec == .legacyMP3 {
            return legacyInfo?.fileName ?? "Legacy MP3"
        }
        return "\(selectedCodec.label) \(roundedBitrateKbps)k"
    }

    var selectedCodecAvailable: Bool {
        switch selectedCodec {
        case .mp3:
            return diagnostics.libmp3lameAvailable
        case .aac:
            return diagnostics.aacAvailable
        case .opus:
            return diagnostics.libopusAvailable
        case .legacyMP3:
            return diagnostics.ffmpegURL != nil
        }
    }

    func isExportItemReady(_ item: ExportPackageItem) -> Bool {
        switch item {
        case .encodedMonitor:
            return renderedArtifacts != nil
        case .differenceWAV:
            return nullTestResult?.differenceFileURL != nil
        case .htmlReport, .jsonReport:
            return referenceInfo != nil
        }
    }

    func currentReport() -> TestReport? {
        guard let referenceInfo else { return nil }
        return TestReport(
            createdAt: Date(),
            reference: referenceInfo,
            region: boundedRegion(for: referenceInfo),
            encodeSettings: renderedArtifacts?.settings,
            nullTestResult: nullTestResult,
            abxSession: abxService.session,
            monitorMode: monitorMode.label,
            notes: nil
        )
    }

    @discardableResult
    func exportPackage(to directory: URL, include items: Set<ExportPackageItem>) throws -> URL {
        let readyItems = Set(items.filter { isExportItemReady($0) })
        guard !readyItems.isEmpty else { throw ExportPackageError.noReadyItems }

        let fileManager = FileManager.default
        let outputFolder = directory.appendingPathComponent(exportFolderName(), isDirectory: true)
        try fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let baseName = exportBaseName
        for item in ExportPackageItem.allCases where readyItems.contains(item) {
            try export(item, baseName: baseName, to: outputFolder)
        }

        statusMessage = "Exported package: \(outputFolder.lastPathComponent)"
        return outputFolder
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

    private func invalidateRenderedMonitor() {
        currentArtifacts = nil
        renderedArtifacts = nil
        nullTestResult = nil
        abxService.reset()
        playbackEngine.removeBuffer(for: .currentMP3)
        playbackEngine.removeBuffer(for: .difference)
    }

    private var exportBaseName: String {
        guard let referenceInfo else { return "CodecLab" }
        let stem = (referenceInfo.fileName as NSString).deletingPathExtension
        return safeFileName(stem.isEmpty ? "CodecLab" : stem)
    }

    private func exportFolderName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "CodecLab_Export_\(exportBaseName)_\(formatter.string(from: Date()))"
    }

    private func export(_ item: ExportPackageItem, baseName: String, to outputFolder: URL) throws {
        switch item {
        case .encodedMonitor:
            guard let renderedArtifacts else { return }
            let displayName = safeFileName(renderedArtifacts.displayName.replacingOccurrences(of: " ", with: "-"))
            let fileExtension = renderedArtifacts.encodedURL.pathExtension.isEmpty
                ? renderedArtifacts.settings.format.rawValue
                : renderedArtifacts.encodedURL.pathExtension
            let destination = outputFolder.appendingPathComponent("\(baseName)-\(displayName).\(fileExtension)")
            try copyReplacingItem(at: renderedArtifacts.encodedURL, to: destination)

        case .differenceWAV:
            guard let differenceURL = nullTestResult?.differenceFileURL else { return }
            let destination = outputFolder.appendingPathComponent("\(baseName)-Difference.wav")
            try copyReplacingItem(at: differenceURL, to: destination)

        case .htmlReport:
            guard let report = currentReport() else { throw ExportPackageError.missingReport }
            let destination = outputFolder.appendingPathComponent("\(baseName)-CodecLab-Report.html")
            try reportExportService.html(for: report).write(to: destination, atomically: true, encoding: .utf8)

        case .jsonReport:
            guard let report = currentReport() else { throw ExportPackageError.missingReport }
            let destination = outputFolder.appendingPathComponent("\(baseName)-CodecLab-Report.json")
            try reportExportService.jsonData(for: report).write(to: destination, options: .atomic)
        }
    }

    private func copyReplacingItem(at source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private func safeFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = value
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "CodecLab" : cleaned
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
