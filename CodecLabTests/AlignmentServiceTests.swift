import XCTest
@testable import CodecLab

final class AlignmentServiceTests: XCTestCase {
    func testFindsPositiveDecodedDelay() {
        let original: [Float] = [0, 0, 1, 0.5, -0.25, 0, 0]
        let decoded: [Float] = [0, 0, 0, 1, 0.5, -0.25, 0, 0]

        let offset = AlignmentService().findBestOffset(original: original, decoded: decoded, maxOffset: 3)

        XCTAssertEqual(offset, -1)
    }
}

