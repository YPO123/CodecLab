import Foundation

struct AlignmentAnalysis: Equatable {
    let offsetSamples: Int
    let overallResidualRMS: Double
    let overallResidualPeak: Double
    let perChannel: [ChannelResidual]
}

struct AlignmentService {
    func analyze(original: MultichannelPCMBuffer, decoded: MultichannelPCMBuffer, maxOffset: Int = 5_000) -> AlignmentAnalysis {
        let channelCount = min(original.channelCount, decoded.channelCount)
        guard channelCount > 0 else {
            return AlignmentAnalysis(offsetSamples: 0, overallResidualRMS: 0, overallResidualPeak: 0, perChannel: [])
        }

        let offset = findBestOffset(
            originalChannels: Array(original.channels.prefix(channelCount)),
            decodedChannels: Array(decoded.channels.prefix(channelCount)),
            maxOffset: maxOffset
        )

        var perChannel = [ChannelResidual]()
        var totalSquares = 0.0
        var totalSamples = 0
        var overallPeak = 0.0

        for channelIndex in 0..<channelCount {
            let metrics = residualMetrics(
                original: original.channels[channelIndex],
                decoded: decoded.channels[channelIndex],
                offset: offset
            )
            totalSquares += metrics.squareSum
            totalSamples += metrics.sampleCount
            overallPeak = max(overallPeak, metrics.peak)

            perChannel.append(ChannelResidual(
                channelIndex: channelIndex,
                channelName: channelName(channelIndex),
                residualRMS: metrics.rms,
                residualPeak: metrics.peak,
                residualRMSdBFS: NullTestResult.dbfs(metrics.rms),
                residualPeakdBFS: NullTestResult.dbfs(metrics.peak)
            ))
        }

        let overallRMS = totalSamples > 0 ? sqrt(totalSquares / Double(totalSamples)) : 0
        return AlignmentAnalysis(
            offsetSamples: offset,
            overallResidualRMS: overallRMS,
            overallResidualPeak: overallPeak,
            perChannel: perChannel
        )
    }

    func findBestOffset(original: [Float], decoded: [Float], maxOffset: Int) -> Int {
        findBestOffset(originalChannels: [original], decodedChannels: [decoded], maxOffset: maxOffset)
    }

    private func findBestOffset(originalChannels: [[Float]], decodedChannels: [[Float]], maxOffset: Int) -> Int {
        var bestOffset = 0
        var bestError = Double.greatestFiniteMagnitude

        for offset in -maxOffset...maxOffset {
            let error = residualRMSForOffset(
                originalChannels: originalChannels,
                decodedChannels: decodedChannels,
                offset: offset
            )
            if error < bestError {
                bestError = error
                bestOffset = offset
            }
        }

        return bestOffset
    }

    private func residualRMSForOffset(originalChannels: [[Float]], decodedChannels: [[Float]], offset: Int) -> Double {
        var squareSum = 0.0
        var sampleCount = 0

        for channelIndex in 0..<min(originalChannels.count, decodedChannels.count) {
            let original = originalChannels[channelIndex]
            let decoded = decodedChannels[channelIndex]
            let analysisCount = min(original.count, decoded.count, 96_000)
            let stride = max(1, analysisCount / 12_000)

            var index = 0
            while index < analysisCount {
                let decodedIndex = index - offset
                if decoded.indices.contains(decodedIndex) {
                    let diff = Double(original[index] - decoded[decodedIndex])
                    squareSum += diff * diff
                    sampleCount += 1
                }
                index += stride
            }
        }

        guard sampleCount > 0 else { return .greatestFiniteMagnitude }
        return sqrt(squareSum / Double(sampleCount))
    }

    private func residualMetrics(original: [Float], decoded: [Float], offset: Int) -> (squareSum: Double, sampleCount: Int, rms: Double, peak: Double) {
        var squareSum = 0.0
        var sampleCount = 0
        var peak = 0.0

        for index in original.indices {
            let decodedIndex = index - offset
            guard decoded.indices.contains(decodedIndex) else { continue }
            let diff = Double(original[index] - decoded[decodedIndex])
            let magnitude = abs(diff)
            squareSum += diff * diff
            peak = max(peak, magnitude)
            sampleCount += 1
        }

        let rms = sampleCount > 0 ? sqrt(squareSum / Double(sampleCount)) : 0
        return (squareSum, sampleCount, rms, peak)
    }

    private func channelName(_ index: Int) -> String {
        let names = ["L", "R", "C", "LFE", "Ls", "Rs", "Lb", "Rb", "Tfl", "Tfr", "Tbl", "Tbr"]
        return index < names.count ? names[index] : "Ch \(index + 1)"
    }
}

