import Foundation

struct NullTestService {
    private let bufferService = MultichannelBufferService()
    private let alignmentService = AlignmentService()
    private let wavExportService = WAVExportService()

    func analyze(
        originalURL: URL,
        decodedURL: URL,
        maxOffset: Int = 5_000,
        differenceOutputURL: URL? = nil
    ) throws -> NullTestResult {
        let original = try bufferService.readFloatBuffer(from: originalURL)
        let decoded = try bufferService.readFloatBuffer(from: decodedURL)
        let analysis = alignmentService.analyze(original: original, decoded: decoded, maxOffset: maxOffset)
        let differenceURL = try writeDifferenceWAV(
            original: original,
            decoded: decoded,
            offset: analysis.offsetSamples,
            outputURL: differenceOutputURL
        )

        return NullTestResult(
            offsetSamples: analysis.offsetSamples,
            overallResidualRMS: analysis.overallResidualRMS,
            overallResidualPeak: analysis.overallResidualPeak,
            perChannel: analysis.perChannel,
            differenceFileURL: differenceURL
        )
    }

    private func writeDifferenceWAV(
        original: MultichannelPCMBuffer,
        decoded: MultichannelPCMBuffer,
        offset: Int,
        outputURL: URL?
    ) throws -> URL? {
        guard let outputURL else { return nil }

        let channels = residualChannels(original: original, decoded: decoded, offset: offset)
        guard !channels.isEmpty else { return nil }

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        try wavExportService.writeFloatWAV(channels: channels, sampleRate: original.sampleRate, to: outputURL)
        return outputURL
    }

    private func residualChannels(
        original: MultichannelPCMBuffer,
        decoded: MultichannelPCMBuffer,
        offset: Int
    ) -> [[Float]] {
        let channelCount = min(original.channelCount, decoded.channelCount)
        guard channelCount > 0 else { return [] }

        let startIndex = max(0, offset)
        let endIndex = min(original.frameCount, decoded.frameCount + offset)
        guard endIndex > startIndex else { return [] }

        return (0..<channelCount).map { channelIndex in
            let originalChannel = original.channels[channelIndex]
            let decodedChannel = decoded.channels[channelIndex]
            var residual = [Float]()
            residual.reserveCapacity(endIndex - startIndex)

            for sampleIndex in startIndex..<endIndex {
                let decodedIndex = sampleIndex - offset
                residual.append(originalChannel[sampleIndex] - decodedChannel[decodedIndex])
            }

            return residual
        }
    }
}
