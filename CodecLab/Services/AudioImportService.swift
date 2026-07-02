import AVFoundation
import Foundation

enum AudioImportError: LocalizedError {
    case unsupportedFile(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return "CodecLab could not read audio metadata from \(url.lastPathComponent)."
        }
    }
}

struct AudioImportService {
    func readInfo(from url: URL) async throws -> AudioFileInfo {
        if let info = try readWithAVAudioFile(url: url) {
            return info
        }
        return try await readFallbackAssetInfo(url: url)
    }

    private func readWithAVAudioFile(url: URL) throws -> AudioFileInfo? {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.fileFormat
            let processingFormat = file.processingFormat
            let sampleRate = processingFormat.sampleRate
            let duration = sampleRate > 0 ? Double(file.length) / sampleRate : 0
            let bitDepth = Int(format.streamDescription.pointee.mBitsPerChannel)
            let channels = Int(format.channelCount)

            return AudioFileInfo(
                url: url,
                fileName: url.deletingPathExtension().lastPathComponent,
                fileExtension: url.pathExtension.lowercased(),
                formatDescription: formatDescription(for: format),
                codecName: codecName(for: url),
                sampleRate: sampleRate,
                bitDepth: bitDepth > 0 ? bitDepth : nil,
                channels: channels,
                channelLayout: channelLayoutDescription(format.channelLayout, channels: channels),
                duration: duration,
                isLossy: isLossy(url)
            )
        } catch {
            return nil
        }
    }

    private func readFallbackAssetInfo(url: URL) async throws -> AudioFileInfo {
        let asset = AVURLAsset(url: url)
        let durationTime = (try? await asset.load(.duration)) ?? .zero
        let duration = CMTimeGetSeconds(durationTime)
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { throw AudioImportError.unsupportedFile(url) }

        return AudioFileInfo(
            url: url,
            fileName: url.deletingPathExtension().lastPathComponent,
            fileExtension: ext,
            formatDescription: codecName(for: url) ?? ext.uppercased(),
            codecName: codecName(for: url),
            sampleRate: 0,
            bitDepth: nil,
            channels: 0,
            channelLayout: nil,
            duration: duration.isFinite ? duration : 0,
            isLossy: isLossy(url)
        )
    }

    private func formatDescription(for format: AVAudioFormat) -> String {
        switch format.commonFormat {
        case .pcmFormatFloat32:
            return "32-bit Float PCM"
        case .pcmFormatFloat64:
            return "64-bit Float PCM"
        case .pcmFormatInt16:
            return "16-bit PCM"
        case .pcmFormatInt32:
            return "32-bit PCM"
        case .otherFormat:
            return codecName(forExtension: nil) ?? "Audio"
        @unknown default:
            return "Audio"
        }
    }

    private func channelLayoutDescription(_ layout: AVAudioChannelLayout?, channels: Int) -> String? {
        if let layout {
            switch layout.layoutTag {
            case kAudioChannelLayoutTag_Mono:
                return "Mono"
            case kAudioChannelLayoutTag_Stereo:
                return "Stereo"
            case kAudioChannelLayoutTag_MPEG_5_1_A:
                return "5.1"
            case kAudioChannelLayoutTag_MPEG_7_1_A:
                return "7.1"
            default:
                break
            }
        }

        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        case 12: return "7.1.4"
        default: return channels > 0 ? "\(channels) channels" : nil
        }
    }

    private func codecName(for url: URL) -> String? {
        codecName(forExtension: url.pathExtension.lowercased())
    }

    private func codecName(forExtension ext: String?) -> String? {
        switch ext {
        case "wav": return "PCM WAV"
        case "aif", "aiff": return "AIFF"
        case "flac": return "FLAC"
        case "mp3": return "MP3"
        case "m4a", "aac", "mp4", "mov": return "AAC / MPEG-4 Audio"
        case "opus": return "Opus"
        default: return nil
        }
    }

    private func isLossy(_ url: URL) -> Bool {
        ["mp3", "aac", "m4a", "mp4", "mov", "opus"].contains(url.pathExtension.lowercased())
    }
}
