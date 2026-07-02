import Foundation

struct ProcessResult: Equatable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String

    var combinedOutput: String {
        [standardOutput, standardError].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum FFmpegServiceError: LocalizedError {
    case missingExecutable
    case commandFailed(arguments: [String], output: String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "FFmpeg executable is missing."
        case .commandFailed(let arguments, let output):
            return "FFmpeg failed: ffmpeg \(arguments.joined(separator: " "))\n\(output)"
        }
    }
}

struct FFmpegService {
    let ffmpegURL: URL

    func extractRegion(input: URL, output: URL, region: TestRegion) async throws {
        try await runChecked([
            "-y",
            "-ss", String(format: "%.6f", region.startTime),
            "-t", String(format: "%.6f", region.duration),
            "-i", input.path,
            "-c:a", "pcm_f32le",
            output.path
        ])
    }

    func encodeCurrentMP3(inputWAV: URL, outputMP3: URL, bitrateKbps: Int) async throws {
        try await runChecked([
            "-y",
            "-i", inputWAV.path,
            "-c:a", "libmp3lame",
            "-b:a", "\(bitrateKbps)k",
            outputMP3.path
        ])
    }

    func encodeAAC(inputWAV: URL, outputM4A: URL, bitrateKbps: Int) async throws {
        try await runChecked([
            "-y",
            "-i", inputWAV.path,
            "-c:a", "aac",
            "-b:a", "\(bitrateKbps)k",
            outputM4A.path
        ])
    }

    func encodeOpus(inputWAV: URL, outputOpus: URL, bitrateKbps: Int) async throws {
        try await runChecked([
            "-y",
            "-i", inputWAV.path,
            "-c:a", "libopus",
            "-b:a", "\(bitrateKbps)k",
            outputOpus.path
        ])
    }

    func decodeToWAV(input: URL, outputWAV: URL) async throws {
        try await runChecked([
            "-y",
            "-i", input.path,
            "-c:a", "pcm_f32le",
            outputWAV.path
        ])
    }

    @discardableResult
    func runChecked(_ arguments: [String]) async throws -> ProcessResult {
        let result = try await run(arguments)
        guard result.terminationStatus == 0 else {
            throw FFmpegServiceError.commandFailed(arguments: arguments, output: result.combinedOutput)
        }
        return result
    }

    func run(_ arguments: [String]) async throws -> ProcessResult {
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            throw FFmpegServiceError.missingExecutable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = ffmpegURL
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { completedProcess in
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(
                    terminationStatus: completedProcess.terminationStatus,
                    standardOutput: output,
                    standardError: error
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

