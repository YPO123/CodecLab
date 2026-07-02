import Foundation

struct LoopRegion: Equatable {
    var startTime: Double
    var endTime: Double

    var duration: Double {
        max(0, endTime - startTime)
    }
}

