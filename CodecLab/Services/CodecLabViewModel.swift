import Combine
import Foundation

enum ABXSlot {
    case a
    case b
    case x
}

enum DeckSide: String, CaseIterable, Identifiable {
    case a
    case b

    var id: String { rawValue }

    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        }
    }

    var playbackSource: MonitorSource {
        switch self {
        case .a: return .original
        case .b: return .currentMP3
        }
    }
}

enum ExportPackageItem: String, CaseIterable, Identifiable, Hashable {
    case encodedMonitor
    case differenceWAV
    case htmlReport
    case jsonReport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .encodedMonitor: return "A/B Audio"
        case .differenceWAV: return "Difference WAV"
        case .htmlReport: return "HTML Report"
        case .jsonReport: return "JSON Report"
        }
    }

    var detail: String {
        switch self {
        case .encodedMonitor: return "Selected deck sources"
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
        case .encodedMonitor: return "A/B"
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

enum DeckPreparationError: LocalizedError {
    case unavailable(String)
    case missingOldAAC
    case missingDeckAudio

    var errorDescription: String? {
        switch self {
        case .unavailable(let codec):
            return "\(codec) is not available with the current FFmpeg setup."
        case .missingOldAAC:
            return "Import an old AAC file before using AAC Old."
        case .missingDeckAudio:
            return "A/B deck audio is not ready yet."
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
    @Published var selectedDeckA: CodecRailFormat = .wav
    @Published var selectedDeckB: CodecRailFormat = .aacNew
    @Published var renderedArtifactsByCodec: [CodecRailFormat: RenderedCodecArtifacts] = [:]
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
            self.renderedArtifactsByCodec = [:]
            self.nullTestResult = nil
            self.playbackEngine.setBuffer(PlaybackBuffer(source: .original, url: url, displayName: info.fileName))
            self.updateDeckBuffers()
            self.statusMessage = "Reference loaded: \(info.fileName)"
        }
    }

    func importLegacyMP3(url: URL) async {
        await importLegacyAAC(url: url)
    }

    func importLegacyAAC(url: URL) async {
        await performBusyOperation("Decoding old AAC...") { [self] in
            let info = try await self.audioImportService.readInfo(from: url)
            let artifacts = try await self.legacyImportService.decodeLegacyMP3(url, diagnostics: self.diagnostics)
            self.legacyInfo = info
            self.legacyArtifacts = artifacts
            self.resetComparisonResult()
            self.updateDeckBuffers()
            self.statusMessage = "Old AAC decoded: \(info.fileName)"
        }
    }

    func generateCurrentMP3() async {
        select(.mp3, for: .b)
        await prepareSelectedDecks()
    }

    func selectCodec(_ codec: CodecRailFormat) {
        select(codec, for: .b)
    }

    func select(_ codec: CodecRailFormat, for side: DeckSide) {
        switch side {
        case .a:
            guard selectedDeckA != codec else { return }
            selectedDeckA = codec
        case .b:
            guard selectedDeckB != codec else { return }
            selectedDeckB = codec
        }
        selectedCodec = selectedDeckB
        resetComparisonResult()
        updateDeckBuffers()
    }

    func selectBitrateKbps(_ bitrate: Int) {
        guard roundedBitrateKbps != bitrate else { return }
        selectedBitrateKbps = Double(bitrate)
        invalidateRenderedCodecs()
    }

    func renderSelectedLossyMonitor() async {
        await prepareSelectedDecks()
    }

    func prepareSelectedDecks() async {
        guard let referenceInfo else {
            statusMessage = "Load a reference audio file first."
            return
        }

        await performBusyOperation("Preparing A/B deck...") { [self] in
            try await self.prepareCodec(self.selectedDeckA, referenceInfo: referenceInfo)
            try await self.prepareCodec(self.selectedDeckB, referenceInfo: referenceInfo)
            self.updateDeckBuffers()
            self.statusMessage = "A/B deck ready: \(self.deckDisplayName(.a)) vs \(self.deckDisplayName(.b))."
        }
    }

    func runNullTestForCurrentMP3() {
        runNullTestForRenderedCodec()
    }

    func runNullTestForRenderedCodec() {
        Task { await runNullTestForDeckSelection() }
    }

    func runNullTestForDeckSelection() async {
        guard let referenceInfo else {
            statusMessage = "Load a reference audio file first."
            return
        }

        await performBusyOperation("Null testing \(deckDisplayName(.a)) against \(deckDisplayName(.b))...") { [self] in
            try await self.prepareCodec(self.selectedDeckA, referenceInfo: referenceInfo)
            try await self.prepareCodec(self.selectedDeckB, referenceInfo: referenceInfo)
            self.updateDeckBuffers()

            guard let aURL = self.playbackURL(for: self.selectedDeckA),
                  let bURL = self.playbackURL(for: self.selectedDeckB) else {
                throw ExportPackageError.noReadyItems
            }

            let outputURL = try self.makeComparisonDirectory()
                .appendingPathComponent("CodecLab Difference A-minus-B.wav")
            let result = try nullTestService.analyze(
                originalURL: aURL,
                decodedURL: bURL,
                differenceOutputURL: outputURL
            )
            nullTestResult = result
            if let differenceFileURL = result.differenceFileURL {
                playbackEngine.setBuffer(PlaybackBuffer(source: .difference, url: differenceFileURL, displayName: "Difference WAV"))
                self.play(.difference)
            }
            statusMessage = "Null Test complete: \(deckDisplayName(.a)) - \(deckDisplayName(.b))."
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
        guard selectedDecksReady else {
            statusMessage = "Prepare the A/B deck before starting ABX."
            return
        }
        abxService.start(totalTrials: totalTrials)
        statusMessage = "ABX started: \(deckDisplayName(.a)) vs \(deckDisplayName(.b))."
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
        guard info.duration.isFinite, info.duration > 0 else { return region }
        return TestRegion(startTime: 0, duration: info.duration)
    }

    var roundedBitrateKbps: Int {
        Int((selectedBitrateKbps / 8).rounded() * 8)
    }

    var lossyMonitorLabel: String {
        deckDisplayName(.b)
    }

    var selectedCodecAvailable: Bool {
        switch selectedCodec {
        case .wav:
            return referenceInfo != nil
        case .mp3:
            return diagnostics.libmp3lameAvailable
        case .aacNew:
            return diagnostics.aacAvailable
        case .aacOld:
            return diagnostics.ffmpegURL != nil
        }
    }

    func isExportItemReady(_ item: ExportPackageItem) -> Bool {
        switch item {
        case .encodedMonitor:
            return selectedDecksReady
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
            encodeSettings: renderedArtifactsByCodec[selectedDeckB]?.settings ?? renderedArtifacts?.settings,
            nullTestResult: nullTestResult,
            abxSession: abxService.session,
            monitorMode: "\(deckDisplayName(.a)) vs \(deckDisplayName(.b))",
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

    var selectedDecksReady: Bool {
        playbackURL(for: selectedDeckA) != nil && playbackURL(for: selectedDeckB) != nil
    }

    var canPrepareSelectedDecks: Bool {
        referenceInfo != nil
            && isCodecSelectable(selectedDeckA)
            && isCodecSelectable(selectedDeckB)
            && !isBusy
    }

    var canRunDeckNullTest: Bool {
        canPrepareSelectedDecks
            && (selectedDeckA != .aacOld || legacyArtifacts != nil)
            && (selectedDeckB != .aacOld || legacyArtifacts != nil)
    }

    func selectedCodec(for side: DeckSide) -> CodecRailFormat {
        switch side {
        case .a: return selectedDeckA
        case .b: return selectedDeckB
        }
    }

    func deckDisplayName(_ side: DeckSide) -> String {
        codecDisplayName(selectedCodec(for: side))
    }

    func deckDetail(_ side: DeckSide) -> String {
        let codec = selectedCodec(for: side)
        if isCodecReady(codec) {
            return codecReadyDetail(codec)
        }
        switch codec {
        case .wav:
            return "Drop WAV"
        case .mp3, .aacNew:
            return "Render needed"
        case .aacOld:
            return "Import old AAC"
        }
    }

    func isCodecReady(_ codec: CodecRailFormat) -> Bool {
        playbackURL(for: codec) != nil
    }

    func isCodecSelectable(_ codec: CodecRailFormat) -> Bool {
        switch codec {
        case .wav:
            return true
        case .mp3:
            return diagnostics.libmp3lameAvailable
        case .aacNew:
            return diagnostics.aacAvailable
        case .aacOld:
            return diagnostics.ffmpegURL != nil
        }
    }

    func codecDisplayName(_ codec: CodecRailFormat) -> String {
        switch codec {
        case .wav:
            return "WAV"
        case .mp3:
            return "MP3 \(roundedBitrateKbps)k"
        case .aacNew:
            return "AAC New \(roundedBitrateKbps)k"
        case .aacOld:
            return legacyInfo?.fileName ?? "AAC Old"
        }
    }

    func codecReadyDetail(_ codec: CodecRailFormat) -> String {
        switch codec {
        case .wav:
            return referenceInfo?.shortFormatSummary ?? "Reference ready"
        case .mp3:
            return "Rendered LAME"
        case .aacNew:
            return "Rendered FFmpeg AAC"
        case .aacOld:
            return "Imported and decoded"
        }
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

    private func resetComparisonResult() {
        nullTestResult = nil
        abxService.reset()
        playbackEngine.removeBuffer(for: .difference)
    }

    private func invalidateRenderedCodecs() {
        currentArtifacts = nil
        renderedArtifacts = nil
        renderedArtifactsByCodec[.mp3] = nil
        renderedArtifactsByCodec[.aacNew] = nil
        resetComparisonResult()
        updateDeckBuffers()
    }

    private func prepareCodec(_ codec: CodecRailFormat, referenceInfo: AudioFileInfo) async throws {
        guard isCodecSelectable(codec) else {
            throw DeckPreparationError.unavailable(codec.label)
        }

        switch codec {
        case .wav:
            return

        case .aacOld:
            guard legacyArtifacts != nil else { throw DeckPreparationError.missingOldAAC }

        case .mp3, .aacNew:
            if renderedArtifactsByCodec[codec] != nil { return }
            guard let format = codec.codecFormat else { throw DeckPreparationError.missingDeckAudio }

            let bitrate = roundedBitrateKbps
            let settings = EncodeSettings(
                format: format,
                encoder: codec.encoderType,
                bitrateKbps: bitrate,
                sampleRate: nil,
                channels: nil,
                downmixMode: nil
            )

            let artifacts = try await encoderService.renderCodec(
                referenceURL: referenceInfo.url,
                region: boundedRegion(for: referenceInfo),
                diagnostics: diagnostics,
                settings: settings
            )
            renderedArtifactsByCodec[codec] = artifacts
            renderedArtifacts = artifacts

            if codec == .mp3 {
                currentArtifacts = CurrentMP3Artifacts(
                    workingDirectory: artifacts.workingDirectory,
                    originalSegmentURL: artifacts.originalSegmentURL,
                    encodedMP3URL: artifacts.encodedURL,
                    decodedWAVURL: artifacts.decodedWAVURL,
                    bitrateKbps: bitrate
                )
            }
        }
    }

    private func updateDeckBuffers() {
        for side in DeckSide.allCases {
            let codec = selectedCodec(for: side)
            if let url = playbackURL(for: codec) {
                playbackEngine.setBuffer(PlaybackBuffer(
                    source: side.playbackSource,
                    url: url,
                    displayName: deckDisplayName(side)
                ))
            } else {
                playbackEngine.removeBuffer(for: side.playbackSource)
            }
        }
    }

    private func playbackURL(for codec: CodecRailFormat) -> URL? {
        switch codec {
        case .wav:
            return referenceInfo?.url
        case .mp3, .aacNew:
            return renderedArtifactsByCodec[codec]?.decodedWAVURL
        case .aacOld:
            return legacyArtifacts?.decodedWAVURL
        }
    }

    private func exportSourceURL(for codec: CodecRailFormat) -> URL? {
        switch codec {
        case .wav:
            return referenceInfo?.url
        case .mp3, .aacNew:
            return renderedArtifactsByCodec[codec]?.encodedURL
        case .aacOld:
            return legacyArtifacts?.sourceMP3URL ?? legacyArtifacts?.decodedWAVURL
        }
    }

    private func exportDeckSource(_ side: DeckSide, baseName: String, to outputFolder: URL) throws {
        let codec = selectedCodec(for: side)
        guard let sourceURL = exportSourceURL(for: codec) else {
            throw DeckPreparationError.missingDeckAudio
        }

        let displayName = safeFileName(codecDisplayName(codec).replacingOccurrences(of: " ", with: "-"))
        let fileExtension = sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension
        let destination = outputFolder.appendingPathComponent("\(baseName)-Deck-\(side.label)-\(displayName).\(fileExtension)")
        try copyReplacingItem(at: sourceURL, to: destination)
    }

    private func makeComparisonDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodecLab", isDirectory: true)
            .appendingPathComponent("Comparison-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
            try exportDeckSource(.a, baseName: baseName, to: outputFolder)
            try exportDeckSource(.b, baseName: baseName, to: outputFolder)

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
