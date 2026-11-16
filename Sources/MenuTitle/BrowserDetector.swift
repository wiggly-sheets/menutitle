import AppKit

enum BrowserDetector {
    static let knownBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "org.chromium.Chromium",
        "app.zen-browser.zen",
        "com.orionbrowser.Orion",
    ]

    private static let knownAliases: [String: [String]] = [
        "com.apple.Safari": ["Safari"],
        "com.apple.SafariTechnologyPreview": ["Safari Technology Preview", "Safari Technology"],
        "com.google.Chrome": ["Google Chrome", "Chrome"],
        "com.google.Chrome.beta": ["Google Chrome Beta", "Chrome Beta", "Chrome"],
        "com.google.Chrome.canary": ["Google Chrome Canary", "Chrome Canary", "Chrome"],
        "org.mozilla.firefox": ["Mozilla Firefox", "Firefox"],
        "com.microsoft.edgemac": ["Microsoft Edge", "Edge"],
        "com.brave.Browser": ["Brave Browser", "Brave"],
        "company.thebrowser.Browser": ["Arc"],
        "com.vivaldi.Vivaldi": ["Vivaldi"],
        "com.operasoftware.Opera": ["Opera"],
        "org.chromium.Chromium": ["Chromium"],
        "app.zen-browser.zen": ["Zen Browser", "Zen"],
        "com.orionbrowser.Orion": ["Orion"],
    ]

    private static let vendorWords: Set<String> = ["google", "microsoft", "mozilla"]
    private static let productSuffixes = [" browser", " technology preview"]

    private static var cachedHandlers: Set<String>?

    static func handlerBundleIDs() -> Set<String> {
        if let cachedHandlers { return cachedHandlers }
        // Link handlers include a few utilities, so stripping still requires the app's own name.
        let probe = URL(string: "https://example.com")!
        let handlers = NSWorkspace.shared.urlsForApplications(toOpen: probe)
        let result = Set(handlers.compactMap { Bundle(url: $0)?.bundleIdentifier })
        cachedHandlers = result
        return result
    }

    static func isBrowser(bundleID: String?, names: [String]) -> Bool {
        if let bundleID {
            if knownBundleIDs.contains(bundleID) || handlerBundleIDs().contains(bundleID) {
                return true
            }
        }
        let known = Set(allKnownAliases.map(normalize))
        return names.map(normalize).contains { known.contains($0) }
    }

    static func aliases(appName: String, bundleID: String?, app: NSRunningApplication?) -> [String] {
        var bases = [appName]
        if let localized = app?.localizedName { bases.append(localized) }
        if let bundleURL = app?.bundleURL {
            bases.append(bundleURL.deletingPathExtension().lastPathComponent)
        }
        if let bundleID, let known = knownAliases[bundleID] {
            bases.append(contentsOf: known)
        }

        var result: Set<String> = []
        for base in bases {
            for variant in variants(of: base) where !variant.isEmpty {
                result.insert(variant)
            }
        }
        return result.sorted()
    }

    static func context(appName: String, pid: pid_t?, customSuffixesText: String) -> TitleCleaner.Context {
        let app = pid.flatMap { NSRunningApplication(processIdentifier: $0) }
        var names = [appName]
        if let localized = app?.localizedName { names.append(localized) }
        let bundleID = app?.bundleIdentifier
        return TitleCleaner.Context(
            isBrowser: isBrowser(bundleID: bundleID, names: names),
            aliases: aliases(appName: appName, bundleID: bundleID, app: app),
            customSuffixes: parseSuffixes(customSuffixesText)
        )
    }

    static var allKnownAliases: [String] {
        knownAliases.values.flatMap { $0 } + knownAliases.values.flatMap { $0.flatMap { variants(of: $0) } }
    }

    static func parseSuffixes(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func variants(of base: String) -> [String] {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var result = [trimmed]
        let words = trimmed.split(separator: " ").map(String.init)
        if words.count > 1 {
            let withoutVendors = words.filter { !vendorWords.contains($0.lowercased()) }
            if !withoutVendors.isEmpty {
                result.append(withoutVendors.joined(separator: " "))
            }
        }

        let lower = trimmed.lowercased()
        for suffix in productSuffixes where lower.hasSuffix(suffix) {
            let shortened = String(trimmed.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            if !shortened.isEmpty { result.append(shortened) }
        }
        return result
    }
}
