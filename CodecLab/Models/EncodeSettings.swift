import Foundation

struct EncodeSettings: Codable, Equatable, Identifiable {
    var id: String {
        [
            format.rawValue,
            encoder.rawValue,
            bitrateKbps.map(String.init) ?? "source",
            sampleRate.map(String.init) ?? "native",
            channels.map(String.init) ?? "native",
            downmixMode ?? "native"
        ].joined(separator: "-")
    }

    let format: CodecFormat
    let encoder: EncoderType
    let bitrateKbps: Int?
    let sampleRate: Int?
    let channels: Int?
    let downmixMode: String?

    var displayName: String {
        if let bitrateKbps {
            return "\(format.label) \(bitrateKbps)k"
        }
        return format.label
    }
}

