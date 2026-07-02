import Foundation

struct CodecPreset: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let settings: [EncodeSettings]

    static let mp3Evolution = CodecPreset(
        id: "mp3-evolution",
        name: "MP3 Evolution Test",
        settings: [
            EncodeSettings(format: .mp3, encoder: .currentLAME, bitrateKbps: 128, sampleRate: nil, channels: nil, downmixMode: nil),
            EncodeSettings(format: .mp3, encoder: .currentLAME, bitrateKbps: 192, sampleRate: nil, channels: nil, downmixMode: nil),
            EncodeSettings(format: .mp3, encoder: .currentLAME, bitrateKbps: 320, sampleRate: nil, channels: nil, downmixMode: nil),
            EncodeSettings(format: .mp3, encoder: .legacyImportedMP3, bitrateKbps: nil, sampleRate: nil, channels: nil, downmixMode: nil)
        ]
    )

    static let clientPreview = CodecPreset(
        id: "client-preview",
        name: "Client Preview Test",
        settings: [
            EncodeSettings(format: .aac, encoder: .ffmpegNativeAAC, bitrateKbps: 192, sampleRate: nil, channels: nil, downmixMode: nil),
            EncodeSettings(format: .aac, encoder: .ffmpegNativeAAC, bitrateKbps: 256, sampleRate: nil, channels: nil, downmixMode: nil),
            EncodeSettings(format: .mp3, encoder: .currentLAME, bitrateKbps: 320, sampleRate: nil, channels: nil, downmixMode: nil)
        ]
    )

    static let streamingStress = CodecPreset(
        id: "streaming-stress",
        name: "Streaming Stress Test",
        settings: [
            EncodeSettings(format: .aac, encoder: .ffmpegNativeAAC, bitrateKbps: 128, sampleRate: nil, channels: nil, downmixMode: nil),
            EncodeSettings(format: .opus, encoder: .libopus, bitrateKbps: 128, sampleRate: nil, channels: nil, downmixMode: nil),
            EncodeSettings(format: .mp3, encoder: .currentLAME, bitrateKbps: 128, sampleRate: nil, channels: nil, downmixMode: nil)
        ]
    )

    static let defaults: [CodecPreset] = [.mp3Evolution, .clientPreview, .streamingStress]
}

