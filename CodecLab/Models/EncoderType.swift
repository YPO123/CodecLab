import Foundation

enum EncoderType: String, Codable, CaseIterable, Identifiable {
    case currentLAME
    case legacyImportedMP3
    case ffmpegNativeAAC
    case libopus
    case appleAAC
    case customExternalEncoder
    case pcm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentLAME: return "Current LAME"
        case .legacyImportedMP3: return "Legacy MP3 Import"
        case .ffmpegNativeAAC: return "FFmpeg AAC"
        case .libopus: return "libopus"
        case .appleAAC: return "Apple AAC"
        case .customExternalEncoder: return "External Encoder"
        case .pcm: return "PCM"
        }
    }
}

