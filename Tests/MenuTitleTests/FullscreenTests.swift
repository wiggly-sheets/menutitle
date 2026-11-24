import XCTest
@testable import MenuTitle

final class FullscreenTests: XCTestCase {
    func testWindowFullscreenFlagIsEnough() {
        XCTAssertTrue(Yabai.isFullscreen(
            window: ["space": 7, "is-native-fullscreen": true],
            space: nil
        ))
    }

    func testFullscreenSpaceIsEnoughWhenWindowFlagIsFalse() {
        XCTAssertTrue(Yabai.isFullscreen(
            window: ["space": 7, "is-native-fullscreen": false],
            space: ["id": 7, "is-native-fullscreen": true]
        ))
    }

    func testSpaceOfAnotherWindowDoesNotCount() {
        XCTAssertFalse(Yabai.isFullscreen(
            window: ["space": 1, "is-native-fullscreen": false],
            space: ["id": 7, "is-native-fullscreen": true]
        ))
        XCTAssertFalse(Yabai.isFullscreen(
            window: ["space": 1, "is-native-fullscreen": false],
            space: ["id": 1, "is-native-fullscreen": false]
        ))
    }
}
