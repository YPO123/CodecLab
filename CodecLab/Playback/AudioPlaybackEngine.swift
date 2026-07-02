import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlaybackEngine: ObservableObject {
    @Published private(set) var activeSource: MonitorSource?
    @Published private(set) var isPlaying = false
    @Published var differenceGainDB: Double = 24

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [MonitorSource: PlaybackBuffer] = [:]

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    func setBuffer(_ buffer: PlaybackBuffer?) {
        guard let buffer else { return }
        buffers[buffer.source] = buffer
    }

    func setBuffers(_ newBuffers: [PlaybackBuffer]) {
        for buffer in newBuffers {
            buffers[buffer.source] = buffer
        }
    }

    func canPlay(_ source: MonitorSource) -> Bool {
        buffers[source] != nil
    }

    func play(_ source: MonitorSource) throws {
        guard let buffer = buffers[source] else { return }
        let file = try AVAudioFile(forReading: buffer.url)

        player.stop()
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

        if !engine.isRunning {
            try engine.start()
        }

        engine.mainMixerNode.outputVolume = source == .difference ? gainScalar(for: differenceGainDB) : 1
        player.scheduleFile(file, at: nil)
        player.play()

        activeSource = source
        isPlaying = true
    }

    func stop() {
        player.stop()
        activeSource = nil
        isPlaying = false
    }

    private func gainScalar(for decibels: Double) -> Float {
        Float(pow(10, decibels / 20))
    }
}

