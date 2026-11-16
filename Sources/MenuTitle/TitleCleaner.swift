import Foundation

enum TitleCleaner {
    struct Context {
        let isBrowser: Bool
        let aliases: [String]
        let customSuffixes: [String]

        init(isBrowser: Bool, aliases: [String], customSuffixes: [String] = []) {
            self.isBrowser = isBrowser
            self.aliases = aliases
            self.customSuffixes = customSuffixes
        }
    }

    private static let separators = [" — ", " – ", " - "]
    private static let maxStripPasses = 4

    private static var legacyContext: Context {
        Context(isBrowser: true, aliases: BrowserDetector.allKnownAliases)
    }

    static func clean(_ title: String, stripBrowserNames: Bool, context: Context? = nil) -> String {
        guard stripBrowserNames else { return title }
        let context = context ?? legacyContext
        guard context.isBrowser else { return title }

        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for _ in 0..<maxStripPasses {
            guard let stripped = strippingTail(result, context: context) else { break }
            guard !stripped.isEmpty else { return title }
            result = stripped
        }
        return result
    }

    private static func strippingTail(_ text: String, context: Context) -> String? {
        for separator in separators {
            guard let range = text.range(of: separator, options: .backwards) else { continue }
            let tail = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
            guard matches(tail, context: context) else { continue }
            let head = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            return head
        }
        return nil
    }

    private static func matches(_ tail: String, context: Context) -> Bool {
        let key = BrowserDetector.normalize(tail)
        guard !key.isEmpty else { return false }
        if context.aliases.contains(where: { BrowserDetector.normalize($0) == key }) {
            return true
        }
        if context.customSuffixes.contains(where: { BrowserDetector.normalize($0) == key }) {
            return true
        }
        return isProfileName(key)
    }

    private static func isProfileName(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard words.count == 2, words[0] == "profile" || words[0] == "person" else { return false }
        return words[1].allSatisfy(\.isNumber)
    }

    static func truncate(_ text: String, maxLength: Int, style: TruncationStyle) -> String {
        guard maxLength > 0, text.count > maxLength else { return text }
        let keep = maxLength - 1
        guard keep > 0 else { return "…" }

        switch style {
        case .end:
            return String(text.prefix(keep)) + "…"
        case .beginning:
            return "…" + String(text.suffix(keep))
        case .middle:
            let head = (keep + 1) / 2
            return String(text.prefix(head)) + "…" + String(text.suffix(keep - head))
        }
    }
}
