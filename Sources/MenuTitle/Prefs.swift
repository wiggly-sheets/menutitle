import AppKit

enum Pref {
    static let fontFamily = "fontFamily"
    static let fontTraits = "fontTraits"
    static let fontSize = "fontSize"
    static let padding = "padding"
    static let paddingLinked = "paddingLinked"
    static let paddingLeft = "paddingLeft"
    static let paddingRight = "paddingRight"
    static let paddingTop = "paddingTop"
    static let paddingBottom = "paddingBottom"
    static let letterSpacing = "letterSpacing"
    static let wordSpacing = "wordSpacing"
    static let gap = "gap"
    static let leftInset = "leftInset"
    static let maxWidth = "maxWidth"
    static let iconStyle = "iconStyle"
    static let iconSizeLinked = "iconSizeLinked"
    static let iconSize = "iconSize"
    static let fontUpdateMode = "fontUpdateMode"
    static let fontInstalledVersion = "fontInstalledVersion"
    static let fontLastCheck = "fontLastCheck"
    static let truncationStyle = "truncationStyle"
    static let maxLength = "maxLength"
    static let scrollTitles = "scrollTitles"
    static let scrollSpeed = "scrollSpeed"
    static let autoScale = "autoScale"
    static let hideOnMenuOpen = "hideOnMenuOpen"
    static let stripBrowserNames = "stripBrowserNames"
    static let customBrowserSuffixes = "customBrowserSuffixes"
    static let backgroundStyle = "backgroundStyle"
    static let useCustomTextColor = "useCustomTextColor"
    static let textColorHex = "textColorHex"
    static let useCustomBackgroundColor = "useCustomBackgroundColor"
    static let backgroundColorHex = "backgroundColorHex"
    static let backgroundOpacity = "backgroundOpacity"
    static let backgroundCornerRadius = "backgroundCornerRadius"
    static let backgroundInsetY = "backgroundInsetY"
    static let leftClickAction = "leftClickAction"
    static let middleClickAction = "middleClickAction"
    static let rightClickAction = "rightClickAction"
    static let showPanel = "showPanel"
    static let showStatusItem = "showStatusItem"
    static let customPosition = "customPosition"
    static let lockPosition = "lockPosition"
    static let panelPosition = "panelPosition"
    static let notchedPosition = "notchedPosition"
    static let notNotchedPosition = "notNotchedPosition"
    static let positionXByDisplay = "positionXByDisplay"
    static let positionYByDisplay = "positionYByDisplay"
    static let statusItemMirrorsTitle = "statusItemMirrorsTitle"
    static let statusItemIconStyle = "statusItemIconStyle"
    static let statusItemFontFamily = "statusItemFontFamily"
    static let statusItemFontTraits = "statusItemFontTraits"
    static let statusItemFontSize = "statusItemFontSize"
    static let statusItemMirrorsClicks = "statusItemMirrorsClicks"
    static let statusItemLeftClickAction = "statusItemLeftClickAction"
    static let statusItemMiddleClickAction = "statusItemMiddleClickAction"
    static let statusItemRightClickAction = "statusItemRightClickAction"

    static let defaults: [String: Any] = [
        fontFamily: "Liga SFMono Nerd Font",
        fontTraits: 0,
        fontSize: 11.0,
        padding: 8.0,
        paddingLinked: true,
        paddingLeft: 8.0,
        paddingRight: 8.0,
        paddingTop: 8.0,
        paddingBottom: 8.0,
        letterSpacing: 0.0,
        wordSpacing: 0.0,
        gap: 6.0,
        leftInset: 0.0,
        maxWidth: 360.0,
        iconStyle: IconStyle.appFont.rawValue,
        iconSizeLinked: true,
        iconSize: 14.0,
        fontUpdateMode: FontUpdateMode.automatic.rawValue,
        fontInstalledVersion: "",
        fontLastCheck: 0.0,
        truncationStyle: TruncationStyle.end.rawValue,
        maxLength: 0,
        scrollTitles: false,
        scrollSpeed: 30.0,
        autoScale: false,
        hideOnMenuOpen: true,
        stripBrowserNames: false,
        customBrowserSuffixes: "",
        backgroundStyle: BarBackgroundStyle.liquidGlass.rawValue,
        useCustomTextColor: false,
        textColorHex: "#FFFFFF",
        useCustomBackgroundColor: false,
        backgroundColorHex: "#1E1E1E",
        backgroundOpacity: 0.95,
        backgroundCornerRadius: 6.0,
        backgroundInsetY: 0.0,
        leftClickAction: ClickAction.openSettings.rawValue,
        middleClickAction: ClickAction.none.rawValue,
        rightClickAction: ClickAction.showMenu.rawValue,
        showPanel: true,
        showStatusItem: false,
        customPosition: false,
        lockPosition: false,
        positionXByDisplay: [String: Double](),
        positionYByDisplay: [String: Double](),
        statusItemMirrorsTitle: true,
        statusItemIconStyle: IconStyle.appFont.rawValue,
        statusItemFontFamily: "Liga SFMono Nerd Font",
        statusItemFontTraits: 0,
        statusItemFontSize: 11.0,
        statusItemMirrorsClicks: true,
        statusItemLeftClickAction: ClickAction.openSettings.rawValue,
        statusItemMiddleClickAction: ClickAction.none.rawValue,
        statusItemRightClickAction: ClickAction.showMenu.rawValue,
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

enum FontUpdateMode: String, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic, daily"
        case .manual: return "Manual"
        }
    }
}

enum ClickAction: String, CaseIterable, Identifiable {
    case none
    case openSettings
    case showMenu
    case focusApp
    case hideApp
    case minimizeApp
    case quitApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .openSettings: return "Open settings"
        case .showMenu: return "Show MenuTitle menu"
        case .focusApp: return "Focus app"
        case .hideApp: return "Hide app"
        case .minimizeApp: return "Minimize app"
        case .quitApp: return "Quit app"
        }
    }
}

enum PlacementMode: String, CaseIterable, Identifiable {
    case titleBar
    case menuBarItem
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .titleBar: return "Title bar"
        case .menuBarItem: return "Menu bar item"
        case .both: return "Both"
        }
    }
}

enum PanelPosition: String, CaseIterable, Identifiable {
    case menus
    case notchLeft
    case notchRight
    case center
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menus: return "Next to app menus"
        case .notchLeft: return "Left of notch"
        case .notchRight: return "Right of notch"
        case .center: return "Centered"
        case .custom: return "Custom position"
        }
    }

    /// Positions that make sense on a display with or without a notch.
    static func options(notched: Bool) -> [PanelPosition] {
        notched ? [.menus, .notchLeft, .notchRight, .custom] : [.menus, .center, .custom]
    }

    /// Stored position for the kind of display being shown. Falls back to the
    /// single old position so existing settings keep working.
    static func current(notched: Bool, defaults: UserDefaults = .standard) -> PanelPosition {
        let key = notched ? Pref.notchedPosition : Pref.notNotchedPosition
        if let raw = defaults.string(forKey: key),
           let position = PanelPosition(rawValue: raw) {
            return position
        }
        let legacy = current(defaults)
        return options(notched: notched).contains(legacy) ? legacy : .menus
    }

    /// Stored position, falling back to the old custom-position toggle so
    /// existing settings keep working.
    static func current(_ defaults: UserDefaults = .standard) -> PanelPosition {
        if let raw = defaults.string(forKey: Pref.panelPosition),
           let position = PanelPosition(rawValue: raw) {
            return position
        }
        return defaults.bool(forKey: Pref.customPosition) ? .custom : .menus
    }
}

enum FontResolver {
    static func font(family: String, size: CGFloat, traits: Int = 0) -> NSFont {
        let mask = NSFontTraitMask(rawValue: UInt(traits))
        if !family.isEmpty,
           let font = NSFontManager.shared.font(
               withFamily: family,
               traits: mask,
               weight: mask.contains(.boldFontMask) ? 9 : 5,
               size: size
           ) {
            return font
        }
        return .systemFont(ofSize: size)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8,
              let number = UInt64(value, radix: 16) else { return nil }

        let hasAlpha = value.count == 8
        let red = CGFloat((number >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((number >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((number >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? CGFloat(number & 0xFF) / 255 : 1
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var hexRGB: String {
        guard let color = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
