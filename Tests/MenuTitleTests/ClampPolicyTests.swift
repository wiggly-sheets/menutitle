import XCTest
@testable import MenuTitle

final class ClampPolicyTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    func testKeepsPanelWhenItIsAlreadyClear() {
        let current = CGRect(x: 300, y: 950, width: 200, height: 32)
        let decision = ClampPolicy.decision(current: current, endX: 100, gap: 6, inset: 0, screen: screen)
        XCTAssertEqual(decision, .keep)
    }

    func testShortTitleStaysVisibleWhenRoomExists() {
        let current = CGRect(x: 0, y: 950, width: 60, height: 32)
        let decision = ClampPolicy.decision(current: current, endX: 100, gap: 6, inset: 0, screen: screen)
        XCTAssertEqual(decision, .move(CGRect(x: 106, y: 950, width: 60, height: 32)))
    }

    func testHidesWhenFreeRoomIsBelowTheMinimum() {
        let narrow = CGRect(x: 0, y: 0, width: 131, height: 982) // 23pt left after x = 106
        let current = CGRect(x: 0, y: 950, width: 60, height: 32)
        let decision = ClampPolicy.decision(current: current, endX: 100, gap: 6, inset: 0, screen: narrow)
        XCTAssertEqual(decision, .hide)
    }

    func testShowsAtExactlyTheMinimumRoom() {
        let narrow = CGRect(x: 0, y: 0, width: 132, height: 982) // 24pt left after x = 106
        let current = CGRect(x: 0, y: 950, width: 60, height: 32)
        let decision = ClampPolicy.decision(current: current, endX: 100, gap: 6, inset: 0, screen: narrow)
        XCTAssertEqual(decision, .move(CGRect(x: 106, y: 950, width: 24, height: 32)))
    }

    func testCapsTheWidthToTheAvailableRoom() {
        let narrow = CGRect(x: 0, y: 0, width: 206, height: 982) // 98pt left after x = 106
        let current = CGRect(x: 0, y: 950, width: 500, height: 32)
        let decision = ClampPolicy.decision(current: current, endX: 100, gap: 6, inset: 0, screen: narrow)
        XCTAssertEqual(decision, .move(CGRect(x: 106, y: 950, width: 98, height: 32)))
    }

    func testGapAndInsetShiftTheOrigin() {
        let current = CGRect(x: 0, y: 950, width: 60, height: 32)
        let decision = ClampPolicy.decision(current: current, endX: 200, gap: 8, inset: 4, screen: screen)
        XCTAssertEqual(decision, .move(CGRect(x: 212, y: 950, width: 60, height: 32)))
    }

    func testScreenMinimumKeepsTheOriginOnScreen() {
        let left = CGRect(x: -1000, y: 0, width: 1512, height: 982)
        let current = CGRect(x: -1000, y: 950, width: 60, height: 32)
        let decision = ClampPolicy.decision(current: current, endX: -3000, gap: 0, inset: 0, screen: left)
        XCTAssertEqual(decision, .move(CGRect(x: -998, y: 950, width: 60, height: 32)))
    }

    func testTrackerStopsAfterFifteenStableReadings() {
        var tracker = StableEndXTracker()
        XCTAssertFalse(tracker.record(100))
        for _ in 0..<14 {
            XCTAssertFalse(tracker.record(100))
        }
        XCTAssertEqual(tracker.stableTicks, 14)
        XCTAssertTrue(tracker.record(100))
        XCTAssertEqual(tracker.stableTicks, 15)
    }

    func testTrackerResetsOnAChangedEndX() {
        var tracker = StableEndXTracker()
        _ = tracker.record(100)
        for _ in 0..<5 {
            _ = tracker.record(100)
        }
        XCTAssertFalse(tracker.record(140))
        XCTAssertEqual(tracker.stableTicks, 0)
        for _ in 0..<14 {
            XCTAssertFalse(tracker.record(140))
        }
        XCTAssertTrue(tracker.record(140))
    }

    func testTrackerResetsOnAMissingEndX() {
        var tracker = StableEndXTracker()
        _ = tracker.record(100)
        for _ in 0..<5 {
            _ = tracker.record(100)
        }
        XCTAssertFalse(tracker.record(nil))
        XCTAssertEqual(tracker.stableTicks, 0)
        XCTAssertFalse(tracker.record(100))
        XCTAssertEqual(tracker.stableTicks, 0)
        for _ in 0..<14 {
            XCTAssertFalse(tracker.record(100))
        }
        XCTAssertTrue(tracker.record(100))
    }

    func testTrackerHiddenPanelResetKeepsTheLastReading() {
        var tracker = StableEndXTracker()
        _ = tracker.record(100)
        _ = tracker.record(100)
        tracker.resetTicks()
        XCTAssertEqual(tracker.stableTicks, 0)
        XCTAssertFalse(tracker.record(100))
        XCTAssertEqual(tracker.stableTicks, 1)
    }
}
