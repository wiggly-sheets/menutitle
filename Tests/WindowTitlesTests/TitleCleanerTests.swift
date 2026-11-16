import XCTest
@testable import WindowTitles

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
