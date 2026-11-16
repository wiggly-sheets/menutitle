import AppKit

enum Pref {
    static let fontFamily = "fontFamily"
    static let fontSize = "fontSize"
    static let padding = "padding"
    static let letterSpacing = "letterSpacing"
    static let wordSpacing = "wordSpacing"
    static let gap = "gap"
    static let leftInset = "leftInset"
    static let maxWidth = "maxWidth"
    static let iconStyle = "iconStyle"
    static let truncationStyle = "truncationStyle"
    static let maxLength = "maxLength"
    static let scrollTitles = "scrollTitles"
    static let autoScale = "autoScale"
    static let hideOnMenuOpen = "hideOnMenuOpen"
    static let stripBrowserNames = "stripBrowserNames"
    static let backgroundStyle = "backgroundStyle"

    static let defaults: [String: Any] = [
        fontFamily: "Liga SFMono Nerd Font",
        fontSize: 11.0,
        padding: 8.0,
        letterSpacing: 0.0,
        wordSpacing: 0.0,
        gap: 6.0,
        leftInset: 0.0,
        maxWidth: 360.0,
        iconStyle: IconStyle.appFont.rawValue,
        truncationStyle: TruncationStyle.end.rawValue,
        maxLength: 0,
        scrollTitles: false,
        autoScale: false,
        hideOnMenuOpen: true,
        stripBrowserNames: false,
        backgroundStyle: BarBackgroundStyle.liquidGlass.rawValue,
    ]
}

enum TruncationStyle: String, CaseIterable, Identifiable {
    case beginning
    case middle
    case end

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginning: return "Beginning"
        case .middle: return "Middle"
        case .end: return "End"
        }
    }
}

enum BarBackgroundStyle: String, CaseIterable, Identifiable {
    case liquidGlass
    case solid
    case transparent
    case outline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liquidGlass: return "Liquid glass"
        case .solid: return "Solid"
        case .transparent: return "Transparent"
        case .outline: return "Outline"
        }
    }
}

enum IconStyle: String, CaseIterable, Identifiable {
    case none
    case appFont
    case native

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .appFont: return "Sketchybar app font"
        case .native: return "Native app icon"
        }
    }
}

enum FontResolver {
    static func font(family: String, size: CGFloat) -> NSFont {
        if !family.isEmpty,
           let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return font
        }
        return .systemFont(ofSize: size)
    }
}
