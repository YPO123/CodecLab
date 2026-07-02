import Foundation

struct CurrentMP3Artifacts: Equatable {
    let workingDirectory: URL
    let originalSegmentURL: URL
    let encodedMP3URL: URL
    let decodedWAVURL: URL
    let bitrateKbps: Int
}

struct EncoderService {
    func generateCurrentMP3(
        referenceURL: URL,
        region: TestRegion,
        diagnostics: EncoderDiagnostics,
        bitrateKbps: Int = 320
    ) async throws -> CurrentMP3Artifacts {
        guard let ffmpegURL = diagnostics.ffmpegURL else {
            throw FFmpegServiceError.missingExecutable
        }
        guard diagnostics.libmp3lameAvailable else {
            throw FFmpegServiceError.commandFailed(
                arguments: ["-encoders"],
                output: "Current MP3 encoder is not available. Please use an FFmpeg build with libmp3lame enabled."
            )
        }

        let directory = try makeWorkingDirectory(prefix: "CurrentMP3")
        let originalSegment = directory.appendingPathComponent("original_segment.wav")
        let encoded = directory.appendingPathComponent("current_mp3_\(bitrateKbps)k.mp3")
        let decoded = directory.appendingPathComponent("current_mp3_\(bitrateKbps)k_decoded.wav")

        let ffmpeg = FFmpegService(ffmpegURL: ffmpegURL)
        try await ffmpeg.extractRegion(input: referenceURL, output: originalSegment, region: region)
        try await ffmpeg.encodeCurrentMP3(inputWAV: originalSegment, outputMP3: encoded, bitrateKbps: bitrateKbps)
        try await ffmpeg.decodeToWAV(input: encoded, outputWAV: decoded)

        return CurrentMP3Artifacts(
            workingDirectory: directory,
            originalSegmentURL: originalSegment,
            encodedMP3URL: encoded,
            decodedWAVURL: decoded,
            bitrateKbps: bitrateKbps
        )
    }

    private func makeWorkingDirectory(prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodecLab", isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

