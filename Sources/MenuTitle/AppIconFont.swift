import AppKit
import CoreText

/// Reads the sketchybar-app-font glyph table (`APPM` in the font's `meta` table)
/// and maps app names to the font's private-use glyphs.
final class AppIconFont {
    static let shared = AppIconFont()
    static let fontName = "sketchybar-app-font"
    static let didChangeNotification = Notification.Name("AppIconFontDidChange")

    static let installURL = URL(
        fileURLWithPath: NSHomeDirectory() + "/Library/Fonts/sketchybar-app-font.ttf"
    )

    static var candidateURLs: [URL] {
        [installURL, URL(fileURLWithPath: "/Library/Fonts/sketchybar-app-font.ttf")]
    }

    private(set) var loaded = false
    private(set) var release = ""
    private(set) var sourceURL: URL?
    private var faceCache: [CGFloat: NSFont] = [:]
    private var exact: [String: String] = [:]
    private var prefixes: [(String, String)] = []
    private var defaultGlyph: String?

    private init() {
        load()
    }

    func glyph(for app: String) -> String? {
        if let glyph = exact[app] { return glyph }
        for (prefix, glyph) in prefixes where app.hasPrefix(prefix) { return glyph }
        return defaultGlyph
    }

    /// The face from the exact file that supplied the glyph table, so a font
    /// update does not keep drawing cached glyphs from the previous release.
    func font(size: CGFloat) -> NSFont? {
        if let cached = faceCache[size] { return cached }
        var resolved: NSFont?
        if let sourceURL,
           let descriptors = CTFontManagerCreateFontDescriptorsFromURL(sourceURL as CFURL)
                as? [CTFontDescriptor],
           let descriptor = descriptors.first {
            resolved = CTFontCreateWithFontDescriptor(descriptor, size, nil) as NSFont
        }
        if resolved == nil {
            resolved = NSFont(name: Self.fontName, size: size)
        }
        if let resolved { faceCache[size] = resolved }
        return resolved
    }

    func reload() {
        loaded = false
        release = ""
        sourceURL = nil
        faceCache.removeAll()
        exact.removeAll()
        prefixes.removeAll()
        defaultGlyph = nil
        load()
    }

    private func load() {
        var best: (url: URL, mapping: Mapping)?

        for url in Self.candidateURLs {
            guard let data = try? Data(contentsOf: url),
                  let mapping = Self.readMapping(data),
                  !mapping.exact.isEmpty else { continue }
            if let current = best {
                if Self.isNewerRelease(mapping.release, than: current.mapping.release) {
                    best = (url, mapping)
                }
            } else {
                best = (url, mapping)
            }
        }

        guard let best else { return }
        CTFontManagerRegisterFontsForURL(best.url as CFURL, .process, nil)
        exact = best.mapping.exact
        prefixes = best.mapping.prefixes
        defaultGlyph = best.mapping.defaultGlyph
        release = best.mapping.release
        sourceURL = best.url
        loaded = true
    }

    private struct Mapping {
        var release: String
        var exact: [String: String]
        var prefixes: [(String, String)]
        var defaultGlyph: String?
    }

    /// True only for data with a readable APPM table and at least one app name.
    static func isValidInstallable(_ data: Data) -> Bool {
        guard let mapping = readMapping(data) else { return false }
        return !mapping.exact.isEmpty
    }

    private static func isNewerRelease(_ candidate: String, than current: String) -> Bool {
        let candidateParts = candidate.trimmingCharacters(in: .letters).split(separator: ".")
        let currentParts = current.trimmingCharacters(in: .letters).split(separator: ".")
        for (left, right) in zip(candidateParts, currentParts) {
            if let leftNumber = Int(left), let rightNumber = Int(right) {
                if leftNumber != rightNumber { return leftNumber > rightNumber }
            } else if left != right {
                return left.lexicographicallyPrecedes(right) == false
            }
        }
        if candidateParts.count != currentParts.count {
            return candidateParts.count > currentParts.count
        }
        return candidate > current
    }

    private static func readMapping(_ data: Data) -> Mapping? {
        func u16(_ offset: Int) -> Int? {
            guard offset >= 0, offset + 2 <= data.count else { return nil }
            return Int(data[offset]) << 8 | Int(data[offset + 1])
        }
        func u32(_ offset: Int) -> Int? {
            guard offset >= 0, offset + 4 <= data.count else { return nil }
            return Int(data[offset]) << 24 | Int(data[offset + 1]) << 16
                | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
        }
        func tag(_ offset: Int) -> String? {
            guard offset >= 0, offset + 4 <= data.count else { return nil }
            return String(data: data[offset..<offset + 4], encoding: .ascii)
        }

        guard data.count > 12, let tableCount = u16(4), tableCount < 4096 else { return nil }
        var metaOffset = 0
        var metaLength = 0
        var foundMeta = false

        for index in 0..<tableCount {
            let record = 12 + index * 16
            guard record + 16 <= data.count else { break }
            if tag(record) == "meta",
               let offset = u32(record + 8),
               let length = u32(record + 12) {
                metaOffset = offset
                metaLength = length
                foundMeta = true
                break
            }
        }
        guard foundMeta, metaLength > 16, metaOffset + metaLength <= data.count,
              let mapCount = u32(metaOffset + 12), mapCount > 0, mapCount < 64 else { return nil }

        for index in 0..<mapCount {
            let record = metaOffset + 16 + index * 12
            guard record + 12 <= data.count else { break }
            guard tag(record) == "APPM",
                  let offsetValue = u32(record + 4),
                  let length = u32(record + 8) else { continue }
            let offset = metaOffset + offsetValue
            guard offset >= metaOffset, offset + length <= data.count else { return nil }
            return parse(data.subdata(in: offset..<offset + length))
        }
        return nil
    }

    private static func parse(_ payload: Data) -> Mapping? {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let icons = object["icons"] as? [[Any]] else { return nil }

        var exact: [String: String] = [:]
        var prefixes: [(String, String)] = []
        var byLigature: [String: String] = [:]

        for icon in icons {
            guard icon.count >= 2,
                  let ligature = icon[0] as? String,
                  let codePoint = (icon[1] as? NSNumber)?.uint32Value,
                  let scalar = UnicodeScalar(codePoint) else { continue }
            let glyph = String(scalar)
            byLigature[ligature] = glyph

            guard icon.count >= 3, let names = icon[2] as? [String] else { continue }
            for name in names {
                if name.hasSuffix("*") {
                    prefixes.append((String(name.dropLast()), glyph))
                } else {
                    exact[name] = glyph
                }
            }
        }

        prefixes.sort { $0.0.count > $1.0.count }
        return Mapping(
            release: object["release"] as? String ?? "",
            exact: exact,
            prefixes: prefixes,
            defaultGlyph: byLigature[":default:"]
        )
    }
}
