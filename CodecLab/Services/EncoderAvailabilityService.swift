import Foundation

struct EncoderDiagnostics: Equatable {
    var ffmpegURL: URL?
    var ffprobeURL: URL?
    var versionLine: String
    var libmp3lameAvailable: Bool
    var aacAvailable: Bool
    var libopusAvailable: Bool
    var lastCheckedAt: Date
    var message: String

    static let unavailable = EncoderDiagnostics(
        ffmpegURL: nil,
        ffprobeURL: nil,
        versionLine: "FFmpeg not found",
        libmp3lameAvailable: false,
        aacAvailable: false,
        libopusAvailable: false,
        lastCheckedAt: Date(),
        message: "Select or bundle an FFmpeg build with libmp3lame enabled."
    )
}

struct EncoderAvailabilityService {
    func diagnostics(customFFmpegURL: URL? = nil) async -> EncoderDiagnostics {
        guard let ffmpegURL = candidateFFmpegURLs(customFFmpegURL: customFFmpegURL).first(where: isExecutable) else {
            return .unavailable
        }

        let version = (try? await runExecutable(ffmpegURL, arguments: ["-hide_banner", "-version"])) ?? ""
        let encoders = (try? await runExecutable(ffmpegURL, arguments: ["-hide_banner", "-encoders"])) ?? ""
        let versionLine = version.components(separatedBy: .newlines).first(where: { !$0.isEmpty }) ?? "FFmpeg detected"

        return EncoderDiagnostics(
            ffmpegURL: ffmpegURL,
            ffprobeURL: ffprobeURL(for: ffmpegURL),
            versionLine: versionLine,
            libmp3lameAvailable: encoders.contains("libmp3lame"),
            aacAvailable: encoders.contains(" aac") || encoders.contains("aac "),
            libopusAvailable: encoders.contains("libopus"),
            lastCheckedAt: Date(),
            message: "Using \(ffmpegURL.path)"
        )
    }

    func candidateFFmpegURLs(customFFmpegURL: URL? = nil) -> [URL] {
        var urls = [URL]()
        if let customFFmpegURL {
            urls.append(customFFmpegURL)
        }
        if let bundled = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) {
            urls.append(bundled)
        }
        urls.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/bin/ffmpeg")
        ])
        return urls
    }

    func ffprobeURL(for ffmpegURL: URL) -> URL? {
        if let bundled = Bundle.main.url(forResource: "ffprobe", withExtension: nil), isExecutable(bundled) {
            return bundled
        }
        let sibling = ffmpegURL.deletingLastPathComponent().appendingPathComponent("ffprobe")
        return isExecutable(sibling) ? sibling : nil
    }

    private func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }

    private func runExecutable(_ executable: URL, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { completedProcess in
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if completedProcess.terminationStatus == 0 {
                    continuation.resume(returning: output + error)
                } else {
                    continuation.resume(returning: output + error)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

