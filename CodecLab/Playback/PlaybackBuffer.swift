import Foundation

enum MonitorSource: String, CaseIterable, Identifiable {
    case original
    case currentMP3
    case legacyMP3
    case difference

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Deck A"
        case .currentMP3: return "Deck B"
        case .legacyMP3: return "Imported"
        case .difference: return "Difference"
        }
    }

    var symbolName: String {
        switch self {
        case .original: return "waveform"
        case .currentMP3: return "switch.2"
        case .legacyMP3: return "clock.arrow.circlepath"
        case .difference: return "plusminus.circle"
        }
    }
}

struct PlaybackBuffer: Identifiable, Equatable {
    let id = UUID()
    let source: MonitorSource
    let url: URL
    let displayName: String
}
