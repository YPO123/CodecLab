import Foundation

enum CodecFormat: String, Codable, CaseIterable, Identifiable {
    case mp3
    case aac
    case opus
    case wav

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .opus: return "Opus"
        case .wav: return "WAV PCM"
        }
    }
}

