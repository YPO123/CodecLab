import Foundation

struct LegacyMP3Artifacts: Equatable {
    let workingDirectory: URL
    let sourceMP3URL: URL
    let decodedWAVURL: URL
}

struct LegacyMP3ImportService {
    func decodeLegacyMP3(_ url: URL, diagnostics: EncoderDiagnostics) async throws -> LegacyMP3Artifacts {
        guard let ffmpegURL = diagnostics.ffmpegURL else {
            throw FFmpegServiceError.missingExecutable
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodecLab", isDirectory: true)
            .appendingPathComponent("LegacyMP3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let decoded = directory.appendingPathComponent("legacy_mp3_decoded.wav")
        try await FFmpegService(ffmpegURL: ffmpegURL).decodeToWAV(input: url, outputWAV: decoded)

        return LegacyMP3Artifacts(workingDirectory: directory, sourceMP3URL: url, decodedWAVURL: decoded)
    }
}

