import Foundation

struct CurrentMP3Artifacts: Equatable {
    let workingDirectory: URL
    let originalSegmentURL: URL
    let encodedMP3URL: URL
    let decodedWAVURL: URL
    let bitrateKbps: Int
}

struct EncoderService {
    func renderCodec(
        referenceURL: URL,
        region: TestRegion,
        diagnostics: EncoderDiagnostics,
        settings: EncodeSettings
    ) async throws -> RenderedCodecArtifacts {
        guard let ffmpegURL = diagnostics.ffmpegURL else {
            throw FFmpegServiceError.missingExecutable
        }
        guard let bitrateKbps = settings.bitrateKbps else {
            throw FFmpegServiceError.commandFailed(arguments: [], output: "Codec rendering needs a bitrate.")
        }

        try validateAvailability(diagnostics: diagnostics, settings: settings)

        let prefix = "\(settings.format.rawValue.uppercased())-\(bitrateKbps)k"
        let directory = try makeWorkingDirectory(prefix: prefix)
        let originalSegment = directory.appendingPathComponent("original_segment.wav")
        let encoded = directory.appendingPathComponent("lossy_\(settings.format.rawValue)_\(bitrateKbps)k.\(fileExtension(for: settings.format))")
        let decoded = directory.appendingPathComponent("lossy_\(settings.format.rawValue)_\(bitrateKbps)k_decoded.wav")

        let ffmpeg = FFmpegService(ffmpegURL: ffmpegURL)
        try await ffmpeg.extractRegion(input: referenceURL, output: originalSegment, region: region)

        switch settings.format {
        case .mp3:
            try await ffmpeg.encodeCurrentMP3(inputWAV: originalSegment, outputMP3: encoded, bitrateKbps: bitrateKbps)
        case .aac:
            try await ffmpeg.encodeAAC(inputWAV: originalSegment, outputM4A: encoded, bitrateKbps: bitrateKbps)
        case .opus:
            try await ffmpeg.encodeOpus(inputWAV: originalSegment, outputOpus: encoded, bitrateKbps: bitrateKbps)
        case .wav:
            try FileManager.default.copyItem(at: originalSegment, to: encoded)
        }

        try await ffmpeg.decodeToWAV(input: encoded, outputWAV: decoded)

        return RenderedCodecArtifacts(
            workingDirectory: directory,
            originalSegmentURL: originalSegment,
            encodedURL: encoded,
            decodedWAVURL: decoded,
            settings: settings
        )
    }

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

    private func validateAvailability(diagnostics: EncoderDiagnostics, settings: EncodeSettings) throws {
        switch settings.encoder {
        case .currentLAME where !diagnostics.libmp3lameAvailable:
            throw FFmpegServiceError.commandFailed(
                arguments: ["-encoders"],
                output: "Current MP3 encoder is not available. Please use an FFmpeg build with libmp3lame enabled."
            )
        case .ffmpegNativeAAC where !diagnostics.aacAvailable:
            throw FFmpegServiceError.commandFailed(arguments: ["-encoders"], output: "AAC encoder is not available in the selected FFmpeg build.")
        case .libopus where !diagnostics.libopusAvailable:
            throw FFmpegServiceError.commandFailed(arguments: ["-encoders"], output: "libopus encoder is not available in the selected FFmpeg build.")
        default:
            break
        }
    }

    private func fileExtension(for format: CodecFormat) -> String {
        switch format {
        case .mp3: return "mp3"
        case .aac: return "m4a"
        case .opus: return "opus"
        case .wav: return "wav"
        }
    }

    private func makeWorkingDirectory(prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodecLab", isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
