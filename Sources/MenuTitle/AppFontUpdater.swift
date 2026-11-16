import CryptoKit
import Foundation
import CoreText
import Darwin

/// GitHub-release updater for the sketchybar-app-font glyph font.
///
/// The font is not bundled. MenuTitle reads the copy in ~/Library/Fonts and
/// downloads the newest release asset when it is missing or auto updates are due.
enum AppFontUpdater {
    struct ReleaseInfo: Equatable {
        let tag: String
        let downloadURL: URL
        let size: Int
        let sha256: String?
    }

    enum CheckResult: Equatable {
        case upToDate(tag: String)
        case updated(ReleaseInfo)
    }

    enum UpdateError: LocalizedError, Equatable {
        case httpStatus(Int)
        case unreadableRelease
        case assetMissing
        case notAFont
        case hashMismatch
        case tooLarge
        case untrustedHost
        case symlinkRefused
        case installFailed

        var errorDescription: String? {
            switch self {
            case .httpStatus(let code) where code == 403 || code == 429:
                return "GitHub rate limit hit. Try again later."
            case .httpStatus(let code): return "GitHub returned HTTP \(code)."
            case .unreadableRelease: return "Could not read the latest release."
            case .assetMissing: return "The latest release has no font file."
            case .notAFont: return "The download is not a usable app font."
            case .hashMismatch: return "The downloaded font does not match its checksum."
            case .tooLarge: return "The font download is larger than expected."
            case .untrustedHost: return "The download came from an untrusted host."
            case .symlinkRefused: return "Refusing to replace a symlinked font file."
            case .installFailed: return "Could not save the font."
            }
        }
    }

    static let assetName = "sketchybar-app-font.ttf"
    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/kvndrsslr/sketchybar-app-font/releases/latest"
    )!
    static let checkInterval: TimeInterval = 24 * 60 * 60
    static let maxDownloadBytes = 20 * 1024 * 1024
    static let downloadTimeout: TimeInterval = 30

    static var installURL: URL { AppIconFont.installURL }

    // MARK: - Pure logic

    static func parseRelease(_ data: Data) throws -> ReleaseInfo {
        struct Payload: Decodable {
            let tag_name: String
            let assets: [Asset]

            struct Asset: Decodable {
                let name: String
                let browser_download_url: String
                let size: Int
                let digest: String?
            }
        }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw UpdateError.unreadableRelease
        }
        guard let asset = payload.assets.first(where: { $0.name == assetName }),
              let url = URL(string: asset.browser_download_url),
              url.scheme == "https" else {
            throw UpdateError.assetMissing
        }
        return ReleaseInfo(
            tag: payload.tag_name,
            downloadURL: url,
            size: asset.size,
            sha256: canonicalDigest(asset.digest)
        )
    }

    static func canonicalDigest(_ raw: String?) -> String? {
        guard var hex = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !hex.isEmpty else { return nil }
        if hex.hasPrefix("sha256:") { hex = String(hex.dropFirst(7)) }
        let isHex = hex.count == 64
            && hex.unicodeScalars.allSatisfy { "0123456789abcdef".unicodeScalars.contains($0) }
        return isHex ? hex : nil
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func isValidFontData(_ data: Data) -> Bool {
        guard data.count > 100_000 else { return false }
        let magic = [UInt8](data.prefix(4))
        return magic == [0x00, 0x01, 0x00, 0x00]
            || magic == Array("true".utf8)
            || magic == Array("OTTO".utf8)
    }

    static func isTrustedDownloadHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "github.com" || host.hasSuffix(".githubusercontent.com")
    }

    // MARK: - Launch and manual checks

    /// Downloads a missing font once, then checks GitHub at most once a day
    /// when automatic updates are on.
    static func startBackground() {
        Task.detached(priority: .utility) {
            let defaults = UserDefaults.standard
            let missing = !AppIconFont.shared.loaded
            let mode = defaults.string(forKey: Pref.fontUpdateMode) ?? FontUpdateMode.automatic.rawValue
            let lastCheck = defaults.double(forKey: Pref.fontLastCheck)
            let due = Date().timeIntervalSince1970 - lastCheck >= checkInterval

            guard missing || (mode == FontUpdateMode.automatic.rawValue && due) else { return }

            do {
                let installed = defaults.string(forKey: Pref.fontInstalledVersion) ?? ""
                switch try await runCheck(installedTag: installed) {
                case .upToDate(let tag):
                    recordCheck(installedTag: tag)
                case .updated(let info):
                    recordCheck(installedTag: info.tag)
                    NSLog("MenuTitle: installed app font \(info.tag)")
                }
            } catch {
                NSLog("MenuTitle: app font update failed — \(error.localizedDescription)")
            }
        }
    }

    static func runCheck(installedTag: String) async throws -> CheckResult {
        let installed = AppIconFont.shared.loaded
            ? (installedTag.isEmpty ? AppIconFont.shared.release : installedTag)
            : ""
        let latest = try await latestRelease()
        guard normalizedTag(installed) != normalizedTag(latest.tag) else {
            return .upToDate(tag: latest.tag)
        }
        try await downloadAndInstall(latest)
        return .updated(latest)
    }

    /// Release tags are "v3.0.25"; the font's own metadata says "3.0.25".
    private static func normalizedTag(_ tag: String) -> String {
        var value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") { value.removeFirst() }
        return value
    }

    static func latestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: downloadTimeout)
        request.setValue("MenuTitle", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let session = URLSession(
            configuration: .ephemeral,
            delegate: RedirectGuard(),
            delegateQueue: nil
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try parseRelease(data)
    }

    static func downloadAndInstall(_ info: ReleaseInfo) async throws {
        guard isTrustedDownloadHost(info.downloadURL) else { throw UpdateError.untrustedHost }
        guard info.size <= maxDownloadBytes else { throw UpdateError.tooLarge }

        var request = URLRequest(url: info.downloadURL, timeoutInterval: downloadTimeout)
        request.setValue("MenuTitle", forHTTPHeaderField: "User-Agent")
        let session = URLSession(
            configuration: .ephemeral,
            delegate: RedirectGuard(),
            delegateQueue: nil
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard data.count <= maxDownloadBytes else { throw UpdateError.tooLarge }
        guard isValidFontData(data), AppIconFont.isValidInstallable(data) else {
            throw UpdateError.notAFont
        }
        if let pinned = info.sha256, sha256Hex(of: data) != pinned {
            throw UpdateError.hashMismatch
        }

        let destination = installURL
        guard !isSymlink(destination) else { throw UpdateError.symlinkRefused }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try secureWrite(data, to: destination)

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(destination as CFURL, .process, &error),
           let unmanaged = error {
            let code = CFErrorGetCode(unmanaged.takeRetainedValue())
            if code != CTFontManagerError.alreadyRegistered.rawValue {
                throw UpdateError.installFailed
            }
        }

        await MainActor.run {
            AppIconFont.shared.reload()
            NotificationCenter.default.post(name: AppIconFont.didChangeNotification, object: nil)
        }
    }

    static func recordCheck(installedTag: String?) {
        let defaults = UserDefaults.standard
        if let installedTag {
            defaults.set(installedTag, forKey: Pref.fontInstalledVersion)
        }
        defaults.set(Date().timeIntervalSince1970, forKey: Pref.fontLastCheck)
    }

    // MARK: - Safe install

    private static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
    }

    /// Write to a fresh 0600 file, then rename over the destination so a
    /// partial download never replaces a working font.
    private static func secureWrite(_ data: Data, to destination: URL) throws {
        guard !isSymlink(destination) else { throw UpdateError.symlinkRefused }
        let directory = destination.deletingLastPathComponent().path
        let temporary = (directory as NSString).appendingPathComponent(
            ".menutitle.font.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString).tmp"
        )
        let fd = open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        guard fd >= 0 else { throw UpdateError.installFailed }
        defer { close(fd) }

        let written = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        guard written == data.count else {
            unlink(temporary)
            throw UpdateError.installFailed
        }
        _ = fchmod(fd, mode_t(0o600))
        guard rename(temporary, destination.path) == 0 else {
            unlink(temporary)
            throw UpdateError.installFailed
        }
    }

    /// Deny redirects that leave the GitHub download hosts.
    private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            guard let url = request.url, isTrustedDownloadHost(url) else {
                completionHandler(nil)
                return
            }
            completionHandler(request)
        }
    }
}
