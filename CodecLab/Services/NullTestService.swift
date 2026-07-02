import Foundation

struct NullTestService {
    private let bufferService = MultichannelBufferService()
    private let alignmentService = AlignmentService()

    func analyze(originalURL: URL, decodedURL: URL, maxOffset: Int = 5_000) throws -> NullTestResult {
        let original = try bufferService.readFloatBuffer(from: originalURL)
        let decoded = try bufferService.readFloatBuffer(from: decodedURL)
        let analysis = alignmentService.analyze(original: original, decoded: decoded, maxOffset: maxOffset)

        return NullTestResult(
            offsetSamples: analysis.offsetSamples,
            overallResidualRMS: analysis.overallResidualRMS,
            overallResidualPeak: analysis.overallResidualPeak,
            perChannel: analysis.perChannel,
            differenceFileURL: nil
        )
    }
}

