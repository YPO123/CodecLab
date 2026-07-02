import Foundation

struct TestRegion: Codable, Equatable {
    var startTime: Double
    var duration: Double

    var endTime: Double {
        startTime + duration
    }

    static let defaultRegion = TestRegion(startTime: 0, duration: 15)
    static let durationPresets: [Double] = [10, 15, 30, 60]
}

