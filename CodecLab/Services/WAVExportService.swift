import AVFoundation
import Foundation

struct WAVExportService {
    func writeFloatWAV(channels: [[Float]], sampleRate: Double, to url: URL) throws {
        guard let firstChannel = channels.first, !firstChannel.isEmpty else {
            throw MultichannelBufferError.emptyFile
        }

        let channelCount = AVAudioChannelCount(channels.count)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(firstChannel.count)) else {
            throw MultichannelBufferError.unsupportedPCMFormat
        }

        buffer.frameLength = AVAudioFrameCount(firstChannel.count)
        guard let output = buffer.floatChannelData else {
            throw MultichannelBufferError.unsupportedPCMFormat
        }

        for channelIndex in 0..<channels.count {
            let source = channels[channelIndex]
            let count = min(source.count, firstChannel.count)
            output[channelIndex].assign(from: source, count: count)
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}

