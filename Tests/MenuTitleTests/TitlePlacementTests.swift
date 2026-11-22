import XCTest
@testable import MenuTitle

final class TitlePlacementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let notch = (left: CGFloat(1000), right: CGFloat(1100))

    private func place(
        _ position: PanelPosition,
        menuEndX: CGFloat = 100,
        gap: CGFloat = 6,
        inset: CGFloat = 0,
        maximumWidth: CGFloat = 360,
        obstructionX: CGFloat? = nil,
        notch: (left: CGFloat, right: CGFloat)? = nil
    ) -> TitlePlacement.Result? {
        TitlePlacement.place(
            position: position,
            screen: screen,
            menuEndX: menuEndX,
            notch: notch,
            gap: gap,
            inset: inset,
            maximumWidth: maximumWidth,
            obstructionX: obstructionX
        )
    }

    func testMenusSitAfterTheMenuEnd() throws {
        let result = try XCTUnwrap(place(.menus))
        XCTAssertEqual(result.anchor, .left(106))
        XCTAssertEqual(result.maximumWidth, 360)
    }

    func testMenusStopAtTheNotch() throws {
        let result = try XCTUnwrap(place(.menus, maximumWidth: 2000, notch: notch))
        XCTAssertEqual(result.maximumWidth, 1000 - 106 - 6)
    }

    func testMenusStopAtAnObstruction() throws {
        let result = try XCTUnwrap(place(.menus, maximumWidth: 2000, obstructionX: 300))
        XCTAssertEqual(result.maximumWidth, 300 - 106 - 6)
    }

    func testNotchLeftEndsBeforeTheNotch() throws {
        let result = try XCTUnwrap(place(.notchLeft, notch: notch))
        XCTAssertEqual(result.anchor, .right(994))
        XCTAssertEqual(result.maximumWidth, 360)
        XCTAssertEqual(result.x(for: 200), 794)
    }

    func testNotchLeftHidesWhenMenusReachTheNotch() {
        XCTAssertNil(place(.notchLeft, menuEndX: 990, notch: notch))
    }

    func testNotchRightStartsAfterTheNotch() throws {
        let result = try XCTUnwrap(place(.notchRight, notch: notch))
        XCTAssertEqual(result.anchor, .left(1106))
        XCTAssertEqual(result.x(for: 100), 1106)
    }

    func testNotchRightStopsAtAnObstruction() throws {
        let result = try XCTUnwrap(place(.notchRight, obstructionX: 1300, notch: notch))
        XCTAssertEqual(result.maximumWidth, 1300 - 1106 - 6)
    }

    func testNotchRightFallsBackToMenusWithoutANotch() throws {
        let result = try XCTUnwrap(place(.notchRight))
        XCTAssertEqual(result.anchor, .left(106))
    }

    func testCenterKeepsTheTitleCentered() throws {
        let result = try XCTUnwrap(place(.center))
        XCTAssertEqual(result.anchor, .center(756))
        XCTAssertEqual(result.x(for: 180), 666)
        XCTAssertEqual(result.maximumWidth, 360)
    }

    func testCenterStopsAtTheMenusAndAnObstruction() throws {
        let result = try XCTUnwrap(place(.center, maximumWidth: 2000, obstructionX: 900))
        XCTAssertEqual(result.maximumWidth, 2 * (900 - 6 - 756))
    }

    func testCenterFallsBackToMenusAtTheNotch() throws {
        let result = try XCTUnwrap(place(.center, notch: notch))
        XCTAssertEqual(result.anchor, .left(106))
    }

    func testCustomUsesTheMenuStartAndScreenWidth() throws {
        let result = try XCTUnwrap(place(.custom, maximumWidth: 2000))
        XCTAssertEqual(result.anchor, .left(106))
        XCTAssertEqual(result.maximumWidth, screen.width - 4)
    }

    func testLegacyCustomToggleStillSelectsCustom() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(true, forKey: Pref.customPosition)
        XCTAssertEqual(PanelPosition.current(defaults), .custom)
    }

    func testStoredPositionWinsOverTheLegacyToggle() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(true, forKey: Pref.customPosition)
        defaults.set(PanelPosition.center.rawValue, forKey: Pref.panelPosition)
        XCTAssertEqual(PanelPosition.current(defaults), .center)
    }

    func testOldNotchPositionStillAppliesToNotchedDisplays() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(PanelPosition.notchRight.rawValue, forKey: Pref.panelPosition)
        XCTAssertEqual(PanelPosition.current(notched: true, defaults: defaults), .notchRight)
        XCTAssertEqual(PanelPosition.current(notched: false, defaults: defaults), .menus)
    }

    func testOldCenterPositionStillAppliesToDisplaysWithoutANotch() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(PanelPosition.center.rawValue, forKey: Pref.panelPosition)
        XCTAssertEqual(PanelPosition.current(notched: true, defaults: defaults), .menus)
        XCTAssertEqual(PanelPosition.current(notched: false, defaults: defaults), .center)
    }

    func testEachDisplayKindKeepsItsOwnPosition() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(PanelPosition.notchLeft.rawValue, forKey: Pref.notchedPosition)
        defaults.set(PanelPosition.center.rawValue, forKey: Pref.notNotchedPosition)
        XCTAssertEqual(PanelPosition.current(notched: true, defaults: defaults), .notchLeft)
        XCTAssertEqual(PanelPosition.current(notched: false, defaults: defaults), .center)
    }
}
