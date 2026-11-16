import AppKit

enum Pref {
    static let fontFamily = "fontFamily"
    static let fontTraits = "fontTraits"
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
    static let leftClickAction = "leftClickAction"
    static let middleClickAction = "middleClickAction"
    static let rightClickAction = "rightClickAction"
    static let showPanel = "showPanel"
    static let showStatusItem = "showStatusItem"
    static let customPosition = "customPosition"
    static let lockPosition = "lockPosition"
    static let positionSet = "positionSet"
    static let positionX = "positionX"
    static let positionY = "positionY"
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
        leftClickAction: ClickAction.openSettings.rawValue,
        middleClickAction: ClickAction.none.rawValue,
        rightClickAction: ClickAction.showMenu.rawValue,
        showPanel: true,
        showStatusItem: false,
        customPosition: false,
        lockPosition: false,
        positionSet: false,
        positionX: 0.0,
        positionY: 0.0,
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
