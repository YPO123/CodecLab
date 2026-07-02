import Foundation

struct AudioDecodeService {
    func decodeToFloatWAV(input: URL, output: URL, diagnostics: EncoderDiagnostics) async throws {
        guard let ffmpegURL = diagnostics.ffmpegURL else {
            throw FFmpegServiceError.missingExecutable
        }
        try await FFmpegService(ffmpegURL: ffmpegURL).decodeToWAV(input: input, outputWAV: output)
    }
}

