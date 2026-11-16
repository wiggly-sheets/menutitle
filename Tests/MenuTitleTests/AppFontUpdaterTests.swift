import XCTest
@testable import MenuTitle

final class AppFontUpdaterTests: XCTestCase {
    func testParsesTheFontAssetFromARelease() throws {
        let digest = String(repeating: "a", count: 64)
        let info = try AppFontUpdater.parseRelease(releaseJSON(digest: "sha256:\(digest)"))

        XCTAssertEqual(info.tag, "v3.0.9")
        XCTAssertEqual(info.size, 351_504)
        XCTAssertEqual(info.sha256, digest)
        XCTAssertEqual(info.downloadURL.host, "github.com")
        XCTAssertEqual(info.downloadURL.lastPathComponent, "sketchybar-app-font.ttf")
    }

    func testRejectsAReleaseWithoutAFontAsset() {
        let json = Data("""
        {"tag_name":"v3.0.9","assets":[
          {"name":"source.zip","browser_download_url":"https://github.com/a.zip","size":10}
        ]}
        """.utf8)
        XCTAssertThrowsError(try AppFontUpdater.parseRelease(json)) { error in
            XCTAssertEqual(error as? AppFontUpdater.UpdateError, .assetMissing)
        }
    }

    func testRejectsAnInsecureDownloadURL() {
        let json = Data("""
        {"tag_name":"v3.0.9","assets":[
          {"name":"sketchybar-app-font.ttf","browser_download_url":"http://example.com/font.ttf","size":10}
        ]}
        """.utf8)
        XCTAssertThrowsError(try AppFontUpdater.parseRelease(json)) { error in
            XCTAssertEqual(error as? AppFontUpdater.UpdateError, .assetMissing)
        }
    }

    func testCanonicalDigestAcceptsOnlyASha256HexString() {
        let digest = String(repeating: "B", count: 64)
        XCTAssertEqual(AppFontUpdater.canonicalDigest("sha256:\(digest)"), digest.lowercased())
        XCTAssertEqual(AppFontUpdater.canonicalDigest(digest), digest.lowercased())
        XCTAssertNil(AppFontUpdater.canonicalDigest(nil))
        XCTAssertNil(AppFontUpdater.canonicalDigest("md5:abc"))
        XCTAssertNil(AppFontUpdater.canonicalDigest(String(repeating: "z", count: 64)))
    }

    func testOnlyGitHubHostsAreTrustedForDownloads() {
        XCTAssertTrue(AppFontUpdater.isTrustedDownloadHost(URL(string: "https://github.com/a.ttf")!))
        XCTAssertTrue(
            AppFontUpdater.isTrustedDownloadHost(URL(string: "https://objects.githubusercontent.com/a.ttf")!)
        )
        XCTAssertFalse(AppFontUpdater.isTrustedDownloadHost(URL(string: "https://example.com/a.ttf")!))
    }

    func testFontDataNeedsSfntMagicAndAPPMetadata() {
        XCTAssertFalse(AppFontUpdater.isValidFontData(Data(repeating: 0, count: 200_000)))
        XCTAssertFalse(AppIconFont.isValidInstallable(Data(repeating: 0, count: 200_000)))

        var trueType = Data([0x00, 0x01, 0x00, 0x00])
        trueType.append(Data(repeating: 0, count: 200_000))
        XCTAssertTrue(AppFontUpdater.isValidFontData(trueType))
        XCTAssertFalse(AppIconFont.isValidInstallable(trueType))
    }

    private func releaseJSON(digest: String) -> Data {
        Data("""
        {
          "tag_name": "v3.0.9",
          "assets": [
            {"name": "source.zip", "browser_download_url": "https://github.com/source.zip", "size": 10},
            {
              "name": "sketchybar-app-font.ttf",
              "browser_download_url": "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v3.0.9/sketchybar-app-font.ttf",
              "size": 351504,
              "digest": "\(digest)"
            }
          ]
        }
        """.utf8)
    }
}
