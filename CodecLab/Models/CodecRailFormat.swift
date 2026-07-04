import Foundation

enum CodecRailFormat: String, CaseIterable, Identifiable, Hashable {
    case wav
    case mp3
    case aacNew
    case aacOld

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wav: return "WAV"
        case .mp3: return "MP3"
        case .aacNew: return "AAC New"
        case .aacOld: return "AAC Old"
        }
    }

    var shortLabel: String {
        switch self {
        case .aacNew: return "AAC New"
        case .aacOld: return "AAC Old"
        default: return label
        }
    }

    var systemImage: String {
        switch self {
        case .wav: return "waveform"
        case .mp3: return "bolt.horizontal.circle"
        case .aacNew: return "sparkles"
        case .aacOld: return "clock.arrow.circlepath"
        }
    }

    var codecFormat: CodecFormat? {
        switch self {
        case .wav: return .wav
        case .mp3: return .mp3
        case .aacNew: return .aac
        case .aacOld: return nil
        }
    }

    var encoderType: EncoderType {
        switch self {
        case .wav: return .pcm
        case .mp3: return .currentLAME
        case .aacNew: return .ffmpegNativeAAC
        case .aacOld: return .legacyImportedAAC
        }
    }

    var isRenderedVariant: Bool {
        switch self {
        case .mp3, .aacNew:
            return true
        case .wav, .aacOld:
            return false
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
