import Foundation

struct TestReport: Codable, Equatable {
    let createdAt: Date
    let reference: AudioFileInfo
    let region: TestRegion
    let encodeSettings: EncodeSettings?
    let nullTestResult: NullTestResult?
    let abxSession: ABXSession?
    let monitorMode: String
    let notes: String?
}

