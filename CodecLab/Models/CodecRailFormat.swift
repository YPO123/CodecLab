import Foundation

enum CodecRailFormat: String, CaseIterable, Identifiable {
    case mp3
    case aac
    case opus
    case legacyMP3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .opus: return "Opus"
        case .legacyMP3: return "Legacy MP3"
        }
    }

    var shortLabel: String {
        switch self {
        case .legacyMP3: return "Legacy"
        default: return label
        }
    }

    var systemImage: String {
        switch self {
        case .mp3: return "bolt.horizontal.circle"
        case .aac: return "sparkles"
        case .opus: return "circle.hexagongrid"
        case .legacyMP3: return "clock.arrow.circlepath"
        }
    }

    var codecFormat: CodecFormat? {
        switch self {
        case .mp3: return .mp3
        case .aac: return .aac
        case .opus: return .opus
        case .legacyMP3: return nil
        }
    }

    var encoderType: EncoderType {
        switch self {
        case .mp3: return .currentLAME
        case .aac: return .ffmpegNativeAAC
        case .opus: return .libopus
        case .legacyMP3: return .legacyImportedMP3
        }
    }
}

struct RenderedCodecArtifacts: Equatable {
    let workingDirectory: URL
    let originalSegmentURL: URL
    let encodedURL: URL
    let decodedWAVURL: URL
    let settings: EncodeSettings

    var displayName: String {
        settings.displayName
    }
}

