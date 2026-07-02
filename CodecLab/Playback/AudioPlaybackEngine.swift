import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlaybackEngine: ObservableObject {
    @Published private(set) var activeSource: MonitorSource?
    @Published private(set) var isPlaying = false
    @Published var differenceGainDB: Double = 24

    private let engine = AVAudioEngine()
    private var players: [MonitorSource: AVAudioPlayerNode] = [:]
    private var buffers: [MonitorSource: PlaybackBuffer] = [:]
    private var deckPrimed = false

    func setBuffer(_ buffer: PlaybackBuffer?) {
        guard let buffer else { return }
        buffers[buffer.source] = buffer
        deckPrimed = false
    }

    func setBuffers(_ newBuffers: [PlaybackBuffer]) {
        for buffer in newBuffers {
            buffers[buffer.source] = buffer
        }
        deckPrimed = false
    }

    func removeBuffer(for source: MonitorSource) {
        buffers[source] = nil
        if activeSource == source {
            stop()
        } else {
            deckPrimed = false
        }
    }

    func canPlay(_ source: MonitorSource) -> Bool {
        buffers[source] != nil
    }

    func play(_ source: MonitorSource) throws {
        guard buffers[source] != nil else { return }

        if isPlaying, deckPrimed {
            setActiveSource(source)
            return
        }

        try startDeck(focusedOn: source)
    }

    func setActiveSource(_ source: MonitorSource) {
        guard buffers[source] != nil else { return }
        for (playerSource, player) in players {
            if playerSource == source {
                player.volume = source == .difference ? gainScalar(for: differenceGainDB) : 1
            } else {
                player.volume = 0
            }
        }
        activeSource = source
    }

    func stop() {
        players.values.forEach { $0.stop() }
        activeSource = nil
        isPlaying = false
        deckPrimed = false
    }

    private func startDeck(focusedOn source: MonitorSource) throws {
        players.values.forEach { $0.stop() }

        for (bufferSource, buffer) in buffers {
            let file = try AVAudioFile(forReading: buffer.url)
            let player = playerNode(for: bufferSource)
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            player.volume = bufferSource == source ? (source == .difference ? gainScalar(for: differenceGainDB) : 1) : 0
            player.scheduleFile(file, at: nil)
        }

        if !engine.isRunning {
            try engine.start()
        }

        players.values.forEach { $0.play() }
        activeSource = source
        isPlaying = true
        deckPrimed = true
    }

    private func playerNode(for source: MonitorSource) -> AVAudioPlayerNode {
        if let player = players[source] {
            return player
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        players[source] = player
        return player
    }

    private func gainScalar(for decibels: Double) -> Float {
        Float(pow(10, decibels / 20))
    }
}
