import Foundation

struct AudioFileInfo: Codable, Identifiable, Equatable {
    var id: URL { url }

    let url: URL
    let fileName: String
    let fileExtension: String
    let formatDescription: String
    let codecName: String?
    let sampleRate: Double
    let bitDepth: Int?
    let channels: Int
    let channelLayout: String?
    let duration: Double
    let isLossy: Bool

    var shortFormatSummary: String {
        var parts = [String]()
        parts.append(sampleRate > 0 ? "\(Int(sampleRate.rounded())) Hz" : "Unknown rate")
        if let bitDepth {
            parts.append("\(bitDepth)-bit")
        }
        parts.append("\(channels) ch")
        parts.append(fileExtension.uppercased())
        return parts.joined(separator: " / ")
    }

    var durationText: String {
        guard duration.isFinite, duration > 0 else { return "Unknown" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

