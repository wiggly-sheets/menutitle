import Foundation

enum TitleCleaner {
    private static let separators = [" — ", " – ", " - "]

    private static let browserNames = [
        "google chrome", "chrome", "mozilla firefox", "firefox", "safari",
        "microsoft edge", "edge", "brave browser", "brave", "arc", "vivaldi",
        "opera", "chromium", "zen browser", "zen", "orion",
    ]

    static func clean(_ title: String, stripBrowserNames: Bool) -> String {
        guard stripBrowserNames else { return title }

        var result = title
        var changed = true
        while changed {
            changed = false
            for separator in separators {
                guard let range = result.range(of: separator, options: .backwards) else { continue }
                let tail = result[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if browserNames.contains(tail.lowercased()) {
                    result = String(result[..<range.lowerBound])
                    changed = true
                    break
                }
            }
        }

        for separator in separators {
            guard let range = result.range(of: separator, options: .backwards) else { continue }
            if isProfileName(result[range.upperBound...].trimmingCharacters(in: .whitespaces)) {
                result = String(result[..<range.lowerBound])
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func isProfileName(_ text: String) -> Bool {
        let words = text.lowercased().split(separator: " ")
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
