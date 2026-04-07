import XCTest
@testable import ClaudeMenuBar

final class PillPositionerTests: XCTestCase {

    func test_notchRight_is_right_of_center() {
        let screenWidth: CGFloat = 2560
        let notchWidth: CGFloat = 210
        let gap: CGFloat = 8
        let expected = screenWidth / 2 + notchWidth / 2 + gap
        let result = PillPositioner.notchRightEdge(screenWidth: screenWidth, notchWidth: notchWidth, gap: gap)
        XCTAssertEqual(result, expected)
    }

    func test_noNotch_positions_at_center_offset() {
        let screenWidth: CGFloat = 1920
        let result = PillPositioner.notchRightEdge(screenWidth: screenWidth, notchWidth: 0, gap: 12)
        XCTAssertEqual(result, screenWidth / 2 + 12)
    }
}
