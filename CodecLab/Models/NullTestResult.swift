import Foundation

struct ChannelResidual: Codable, Identifiable, Equatable {
    var id: Int { channelIndex }

    let channelIndex: Int
    let channelName: String?
    let residualRMS: Double
    let residualPeak: Double
    let residualRMSdBFS: Double
    let residualPeakdBFS: Double
}

struct NullTestResult: Codable, Equatable {
    let offsetSamples: Int
    let overallResidualRMS: Double
    let overallResidualPeak: Double
    let perChannel: [ChannelResidual]
    let differenceFileURL: URL?

    var overallResidualRMSdBFS: Double {
        Self.dbfs(overallResidualRMS)
    }

    var overallResidualPeakdBFS: Double {
        Self.dbfs(overallResidualPeak)
    }

    static func dbfs(_ value: Double) -> Double {
        guard value > 0 else { return -.infinity }
        return 20 * log10(value)
    }
}

