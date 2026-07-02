import AVFoundation
import Foundation

struct MultichannelPCMBuffer: Equatable {
    let sampleRate: Double
    let frameCount: Int
    let channels: [[Float]]

    var channelCount: Int {
        channels.count
    }
}

enum MultichannelBufferError: LocalizedError {
    case emptyFile
    case unsupportedPCMFormat

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "Audio file is empty."
        case .unsupportedPCMFormat:
            return "CodecLab could not read this file as non-interleaved float PCM."
        }
    }
}

struct MultichannelBufferService {
    func readFloatBuffer(from url: URL) throws -> MultichannelPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else { throw MultichannelBufferError.emptyFile }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw MultichannelBufferError.unsupportedPCMFormat
        }
        try file.read(into: buffer)

        guard let floatData = buffer.floatChannelData else {
            throw MultichannelBufferError.unsupportedPCMFormat
        }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let channels = (0..<channelCount).map { channelIndex in
            Array(UnsafeBufferPointer(start: floatData[channelIndex], count: frameLength))
        }

        return MultichannelPCMBuffer(
            sampleRate: buffer.format.sampleRate,
            frameCount: frameLength,
            channels: channels
        )
    }
}

