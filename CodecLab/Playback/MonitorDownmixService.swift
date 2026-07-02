import Foundation

enum MonitorMode: String, CaseIterable, Identifiable {
    case nativeMultichannel
    case stereoDownmix

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nativeMultichannel: return "Native Multichannel"
        case .stereoDownmix: return "Stereo Downmix"
        }
    }
}

struct MonitorDownmixService {
    func preferredMode(outputChannelCount: Int, sourceChannelCount: Int) -> MonitorMode {
        outputChannelCount >= sourceChannelCount ? .nativeMultichannel : .stereoDownmix
    }
}

