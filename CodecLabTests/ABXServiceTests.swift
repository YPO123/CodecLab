import XCTest
@testable import CodecLab

final class ABXServiceTests: XCTestCase {
    func testPValueForAllCorrectTenTrials() {
        XCTAssertEqual(ABXService.pValue(correct: 10, total: 10), 0.0009765625, accuracy: 0.0000001)
    }

    func testPValueForEightOfTenTrials() {
        XCTAssertEqual(ABXService.pValue(correct: 8, total: 10), 0.0546875, accuracy: 0.0000001)
    }
}

