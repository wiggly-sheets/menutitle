import XCTest
@testable import MenuTitle

final class TitleCleanerTests: XCTestCase {
    func testStripsBrowserAndProfileNames() {
        XCTAssertEqual(TitleCleaner.clean("Page - Google Chrome", stripBrowserNames: true), "Page")
        XCTAssertEqual(
            TitleCleaner.clean("Page - Profile 1 - Microsoft Edge", stripBrowserNames: true),
            "Page"
        )
        XCTAssertEqual(TitleCleaner.clean("Page — Mozilla Firefox", stripBrowserNames: true), "Page")
        XCTAssertEqual(TitleCleaner.clean("Page – Mozilla Firefox", stripBrowserNames: true), "Page")
        XCTAssertEqual(TitleCleaner.clean("Page - GOOGLE CHROME", stripBrowserNames: true), "Page")
    }

    func testKeepsNamesWhenStrippingIsOff() {
        XCTAssertEqual(TitleCleaner.clean("Page - Google Chrome", stripBrowserNames: false), "Page - Google Chrome")
    }

    func testKeepsOrdinarySuffixes() {
        XCTAssertEqual(TitleCleaner.clean("Notes – 64 notes", stripBrowserNames: true), "Notes – 64 notes")
    }

    func testDoesNotTreatProfileLikeSuffixAsProfileName() {
        XCTAssertEqual(
            TitleCleaner.clean("Page - Profile Settings", stripBrowserNames: true),
            "Page - Profile Settings"
        )
    }

    func testStripsNamesFromTheFrontBrowserApp() {
        let brave = browser("Brave Browser")
        XCTAssertEqual(TitleCleaner.clean("Page - Brave", stripBrowserNames: true, context: brave), "Page")
        XCTAssertEqual(TitleCleaner.clean("Page - Brave Browser", stripBrowserNames: true, context: brave), "Page")

        let chrome = browser("Google Chrome")
        XCTAssertEqual(TitleCleaner.clean("Page - Chrome", stripBrowserNames: true, context: chrome), "Page")
        XCTAssertEqual(TitleCleaner.clean("Page - GOOGLE CHROME", stripBrowserNames: true, context: chrome), "Page")

        let safariPreview = browser("Safari Technology Preview")
        XCTAssertEqual(
            TitleCleaner.clean("Page - Safari Technology Preview", stripBrowserNames: true, context: safariPreview),
            "Page"
        )
    }

    func testStripsProfileOnlyInsideBrowsers() {
        let chrome = browser("Google Chrome")
        XCTAssertEqual(TitleCleaner.clean("Page - Profile 12", stripBrowserNames: true, context: chrome), "Page")
        XCTAssertEqual(TitleCleaner.clean("Page - Person 2", stripBrowserNames: true, context: chrome), "Page")
        XCTAssertEqual(
            TitleCleaner.clean("Page - Profile 12", stripBrowserNames: true, context: nonBrowser("Notes")),
            "Page - Profile 12"
        )
    }

    func testDoesNotStripInOtherApps() {
        let notes = nonBrowser("Notes")
        XCTAssertEqual(
            TitleCleaner.clean("Budget - Chrome", stripBrowserNames: true, context: notes),
            "Budget - Chrome"
        )
    }

    func testDoesNotStripAnotherBrowsersName() {
        let firefox = browser("Firefox")
        XCTAssertEqual(
            TitleCleaner.clean("Page - Google Chrome", stripBrowserNames: true, context: firefox),
            "Page - Google Chrome"
        )
    }

    func testStripsCustomSuffixesOnlyInBrowsers() {
        let browserContext = browser("Google Chrome", custom: ["YouTube", "Notion"])
        XCTAssertEqual(
            TitleCleaner.clean("Video - YouTube", stripBrowserNames: true, context: browserContext),
            "Video"
        )
        XCTAssertEqual(
            TitleCleaner.clean("Video - YouTube", stripBrowserNames: true, context: nonBrowser("Notes")),
            "Video - YouTube"
        )
    }

    func testLeavesTitleAloneWhenStrippingWouldEmptyIt() {
        let chrome = browser("Google Chrome")
        XCTAssertEqual(TitleCleaner.clean("Chrome", stripBrowserNames: true, context: chrome), "Chrome")
        XCTAssertEqual(TitleCleaner.clean(" - Chrome", stripBrowserNames: true, context: chrome), "- Chrome")
    }

    private func browser(_ appName: String, custom: [String] = []) -> TitleCleaner.Context {
        TitleCleaner.Context(
            isBrowser: true,
            aliases: BrowserDetector.aliases(appName: appName, bundleID: nil, app: nil),
            customSuffixes: custom
        )
    }

    private func nonBrowser(_ appName: String) -> TitleCleaner.Context {
        TitleCleaner.Context(
            isBrowser: false,
            aliases: BrowserDetector.aliases(appName: appName, bundleID: nil, app: nil)
        )
    }

    func testTruncatesAtEachStyle() {
        let text = "abcdefghijklmnop"
        XCTAssertEqual(TitleCleaner.truncate(text, maxLength: 10, style: .end), "abcdefghi…")
        XCTAssertEqual(TitleCleaner.truncate(text, maxLength: 10, style: .beginning), "…hijklmnop")
        XCTAssertEqual(TitleCleaner.truncate(text, maxLength: 10, style: .middle), "abcde…mnop")
    }

    func testTruncateDoesNothingWhenOffOrShortEnough() {
        XCTAssertEqual(TitleCleaner.truncate("Short", maxLength: 0, style: .end), "Short")
        XCTAssertEqual(TitleCleaner.truncate("Short", maxLength: 10, style: .end), "Short")
    }

    func testTruncateKeepsTextAtExactMaxLength() {
        XCTAssertEqual(TitleCleaner.truncate("abcdefghij", maxLength: 10, style: .end), "abcdefghij")
    }

    func testTruncateToOneCharacterIsEllipsis() {
        XCTAssertEqual(TitleCleaner.truncate("abc", maxLength: 1, style: .end), "…")
    }
}
