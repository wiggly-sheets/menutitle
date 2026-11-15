import AppKit
import CoreText

/// Reads the sketchybar-app-font glyph table (`APPM` in the font's `meta` table)
/// and maps app names to the font's private-use glyphs.
final class AppIconFont {
    static let shared = AppIconFont()
    static let fontName = "sketchybar-app-font"

    private(set) var loaded = false
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

    private func load() {
        let paths = [
            NSHomeDirectory() + "/Library/Fonts/sketchybar-app-font.ttf",
            "/Library/Fonts/sketchybar-app-font.ttf",
        ]
        guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }

        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: path) as CFURL, .process, nil)

        guard let mapping = Self.readMapping(data), !mapping.exact.isEmpty else { return }
        exact = mapping.exact
        prefixes = mapping.prefixes
        defaultGlyph = mapping.defaultGlyph
        loaded = true
    }

    private struct Mapping {
        var exact: [String: String]
        var prefixes: [(String, String)]
        var defaultGlyph: String?
    }

    private static func readMapping(_ data: Data) -> Mapping? {
        func u16(_ offset: Int) -> Int {
            Int(data[offset]) << 8 | Int(data[offset + 1])
        }
        func u32(_ offset: Int) -> Int {
            Int(data[offset]) << 24 | Int(data[offset + 1]) << 16
                | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
        }
        func tag(_ offset: Int) -> String? {
            String(data: data[offset..<offset + 4], encoding: .ascii)
        }

        guard data.count > 12 else { return nil }
        let tableCount = u16(4)
        var metaOffset = 0
        var metaLength = 0
        var foundMeta = false

        for index in 0..<tableCount {
            let record = 12 + index * 16
            guard record + 16 <= data.count else { break }
            if tag(record) == "meta" {
                metaOffset = u32(record + 8)
                metaLength = u32(record + 12)
                foundMeta = true
                break
            }
        }
        guard foundMeta, metaLength > 16, metaOffset + metaLength <= data.count else { return nil }

        let mapCount = u32(metaOffset + 12)
        guard mapCount < 64 else { return nil }

        for index in 0..<mapCount {
            let record = metaOffset + 16 + index * 12
            guard record + 12 <= data.count else { break }
            guard tag(record) == "APPM" else { continue }

            let offset = metaOffset + u32(record + 4)
            let length = u32(record + 8)
            guard offset + length <= data.count else { return nil }
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
        return Mapping(exact: exact, prefixes: prefixes, defaultGlyph: byLigature[":default:"])
    }
}
