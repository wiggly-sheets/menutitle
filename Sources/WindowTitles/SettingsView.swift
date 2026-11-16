import AppKit
import ApplicationServices
import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case appearance
    case placement
    case clicking
    case title
    case position
    case general
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "Appearance"
        case .placement: return "Placement"
        case .clicking: return "Clicking"
        case .title: return "Title"
        case .position: return "Position"
        case .general: return "General"
        case .permissions: return "Permissions"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .placement: return "rectangle.3.group"
        case .clicking: return "cursorarrow.click"
        case .title: return "textformat"
        case .position: return "arrow.left.and.right"
        case .general: return "gearshape"
        case .permissions: return "lock.shield"
        }
    }
}

struct SettingsView: View {
    @AppStorage(Pref.fontFamily) private var fontFamily = "Liga SFMono Nerd Font"
    @AppStorage(Pref.fontTraits) private var fontTraits = 0
    @AppStorage(Pref.fontSize) private var fontSize = 11.0
    @AppStorage(Pref.padding) private var padding = 8.0
    @AppStorage(Pref.letterSpacing) private var letterSpacing = 0.0
    @AppStorage(Pref.wordSpacing) private var wordSpacing = 0.0
    @AppStorage(Pref.gap) private var gap = 6.0
    @AppStorage(Pref.leftInset) private var leftInset = 0.0
    @AppStorage(Pref.maxWidth) private var maxWidth = 360.0
    @AppStorage(Pref.iconStyle) private var iconStyle = IconStyle.appFont.rawValue
    @AppStorage(Pref.backgroundStyle) private var backgroundStyle = BarBackgroundStyle.liquidGlass.rawValue
    @AppStorage(Pref.useCustomTextColor) private var useCustomTextColor = false
    @AppStorage(Pref.textColorHex) private var textColorHex = "#FFFFFF"
    @AppStorage(Pref.useCustomBackgroundColor) private var useCustomBackgroundColor = false
    @AppStorage(Pref.backgroundColorHex) private var backgroundColorHex = "#1E1E1E"
    @AppStorage(Pref.backgroundOpacity) private var backgroundOpacity = 0.95
    @AppStorage(Pref.backgroundCornerRadius) private var backgroundCornerRadius = 6.0
    @AppStorage(Pref.backgroundInsetY) private var backgroundInsetY = 0.0
    @AppStorage(Pref.truncationStyle) private var truncationStyle = TruncationStyle.end.rawValue
    @AppStorage(Pref.maxLength) private var maxLength = 0
    @AppStorage(Pref.scrollTitles) private var scrollTitles = false
    @AppStorage(Pref.autoScale) private var autoScale = false
    @AppStorage(Pref.hideOnMenuOpen) private var hideOnMenuOpen = true
    @AppStorage(Pref.stripBrowserNames) private var stripBrowserNames = false
    @AppStorage(Pref.leftClickAction) private var leftClickAction = ClickAction.openSettings.rawValue
    @AppStorage(Pref.middleClickAction) private var middleClickAction = ClickAction.none.rawValue
    @AppStorage(Pref.rightClickAction) private var rightClickAction = ClickAction.showMenu.rawValue
    @AppStorage(Pref.showPanel) private var showPanel = true
    @AppStorage(Pref.showStatusItem) private var showStatusItem = false
    @AppStorage(Pref.statusItemMirrorsTitle) private var statusItemMirrorsTitle = true
    @AppStorage(Pref.statusItemIconStyle) private var statusItemIconStyle = IconStyle.appFont.rawValue
    @AppStorage(Pref.statusItemFontFamily) private var statusItemFontFamily = "Liga SFMono Nerd Font"
    @AppStorage(Pref.statusItemFontTraits) private var statusItemFontTraits = 0
    @AppStorage(Pref.statusItemFontSize) private var statusItemFontSize = 11.0
    @AppStorage(Pref.statusItemMirrorsClicks) private var statusItemMirrorsClicks = true
    @AppStorage(Pref.statusItemLeftClickAction) private var statusItemLeftClickAction = ClickAction.openSettings.rawValue
    @AppStorage(Pref.statusItemMiddleClickAction) private var statusItemMiddleClickAction = ClickAction.none.rawValue
    @AppStorage(Pref.statusItemRightClickAction) private var statusItemRightClickAction = ClickAction.showMenu.rawValue
    @AppStorage(Pref.customPosition) private var customPosition = false
    @AppStorage(Pref.lockPosition) private var lockPosition = false

    @State private var pane: SettingsPane? = .appearance
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?
    @State private var loginNeedsApproval = LaunchAtLogin.needsApproval
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    private var previewFont: Font {
        Font(FontResolver.font(family: fontFamily, size: fontSize, traits: fontTraits))
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: textColorHex) ?? .labelColor) },
            set: { textColorHex = NSColor($0).hexRGB }
        )
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: backgroundColorHex) ?? .windowBackgroundColor) },
            set: { backgroundColorHex = NSColor($0).hexRGB }
        )
    }

    private var placementMode: Binding<PlacementMode> {
        Binding(
            get: {
                if showPanel && showStatusItem { return .both }
                if showStatusItem { return .menuBarItem }
                return .titleBar
            },
            set: { mode in
                showPanel = mode != .menuBarItem
                showStatusItem = mode != .titleBar
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 185, max: 220)
        } detail: {
            Group {
                if let pane {
                    Form {
                        content(for: pane)
                    }
                    .formStyle(.grouped)
                } else {
                    Text("Select a setting")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .onAppear {
            accessibilityTrusted = AXIsProcessTrusted()
            launchAtLogin = LaunchAtLogin.isEnabled
            loginNeedsApproval = LaunchAtLogin.needsApproval
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = AXIsProcessTrusted()
        }
    }

    @ViewBuilder
    private func content(for pane: SettingsPane) -> some View {
        switch pane {
        case .appearance: appearance
        case .placement: placement
        case .clicking: clicking
        case .title: titleSettings
        case .position: position
        case .general: general
        case .permissions: permissions
        }
    }

    @ViewBuilder
    private var appearance: some View {
        Section {
            Picker("Next to the title", selection: $iconStyle) {
                ForEach(IconStyle.allCases) { style in
                    Text(style.title).tag(style.rawValue)
                }
            }

            HStack {
                Text("Font").frame(width: 120, alignment: .leading)
                Text(fontDescription(fontFamily, fontTraits))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                FontPanelButton(family: $fontFamily, size: $fontSize, traits: $fontTraits)
            }

            sliderRow("Size", value: $fontSize, range: 8...18, unit: "pt")
            sliderRow("Padding", value: $padding, range: 0...24, unit: "pt")
            sliderRow("Letter spacing", value: $letterSpacing, range: -1...5, step: 0.5, unit: "pt")
            sliderRow("Word spacing", value: $wordSpacing, range: 0...12, unit: "pt")

            Picker("Background", selection: $backgroundStyle) {
                ForEach(BarBackgroundStyle.allCases) { style in
                    Text(style.title).tag(style.rawValue)
                }
            }

            if backgroundStyle != BarBackgroundStyle.transparent.rawValue {
                Toggle("Custom background color", isOn: $useCustomBackgroundColor)
                if useCustomBackgroundColor {
                    ColorPicker("Background color", selection: backgroundColorBinding, supportsOpacity: false)
                }
                sliderRow("Opacity", value: $backgroundOpacity, range: 0...1, step: 0.05, unit: "")
                sliderRow("Corner radius", value: $backgroundCornerRadius, range: 0...24, unit: "pt")
                sliderRow("Shape height inset", value: $backgroundInsetY, range: 0...14, unit: "pt")
            }

            Toggle("Custom text color", isOn: $useCustomTextColor)
            if useCustomTextColor {
                ColorPicker("Text color", selection: textColorBinding, supportsOpacity: false)
            }

            HStack {
                Spacer()
                Text("Window Title")
                    .font(previewFont)
                    .foregroundColor(useCustomTextColor ? textColorBinding.wrappedValue : .secondary)
                Spacer()
            }
        } header: {
            Text("Appearance")
        } footer: {
            if iconStyle == IconStyle.appFont.rawValue && !AppIconFont.shared.loaded {
                Text("sketchybar-app-font.ttf was not found in ~/Library/Fonts or /Library/Fonts. Choose another icon style or install the font.")
            } else {
                Text("The font panel sets the family, style, and size. The size slider stays in sync. Shape height inset makes the background shorter than the menu bar.")
            }
        }
    }

    @ViewBuilder
    private var placement: some View {
        Section {
            Picker("Show", selection: placementMode) {
                ForEach(PlacementMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if showPanel {
                Toggle("Use custom position", isOn: $customPosition)
                if customPosition {
                    Toggle("Lock position", isOn: $lockPosition)
                    Text("Drag the title to move it. The position is remembered.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Where to show")
        } footer: {
            Text("Both can be shown at once. The menu bar item always uses the same title text.")
        }

        if showStatusItem {
            Section {
                Toggle("Use title appearance", isOn: $statusItemMirrorsTitle)

                if !statusItemMirrorsTitle {
                    Picker("Item icon", selection: $statusItemIconStyle) {
                        ForEach(IconStyle.allCases) { style in
                            Text(style.title).tag(style.rawValue)
                        }
                    }

                    HStack {
                        Text("Item font").frame(width: 120, alignment: .leading)
                        Text(fontDescription(statusItemFontFamily, statusItemFontTraits))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        FontPanelButton(
                            family: $statusItemFontFamily,
                            size: $statusItemFontSize,
                            traits: $statusItemFontTraits
                        )
                    }

                    sliderRow("Item size", value: $statusItemFontSize, range: 8...18, unit: "pt")
                }
            } header: {
                Text("Menu bar item")
            } footer: {
                Text("Turn off Use title appearance to give the menu bar item its own font and icon.")
            }
        }
    }

    @ViewBuilder
    private var clicking: some View {
        Section {
            Picker("Left click", selection: $leftClickAction) {
                ForEach(ClickAction.allCases) { action in
                    Text(action.title).tag(action.rawValue)
                }
            }
            Picker("Middle click", selection: $middleClickAction) {
                ForEach(ClickAction.allCases) { action in
                    Text(action.title).tag(action.rawValue)
                }
            }
            Picker("Right click", selection: $rightClickAction) {
                ForEach(ClickAction.allCases) { action in
                    Text(action.title).tag(action.rawValue)
                }
            }
        } header: {
            Text("Title clicks")
        } footer: {
            Text("App actions apply to the app that owns the shown window.")
        }

        if showStatusItem {
            Section {
                Toggle("Menu bar item uses these actions", isOn: $statusItemMirrorsClicks)
                if !statusItemMirrorsClicks {
                    Picker("Item left click", selection: $statusItemLeftClickAction) {
                        ForEach(ClickAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    Picker("Item middle click", selection: $statusItemMiddleClickAction) {
                        ForEach(ClickAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    Picker("Item right click", selection: $statusItemRightClickAction) {
                        ForEach(ClickAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                }
            } header: {
                Text("Menu bar item clicks")
            }
        }
    }

    @ViewBuilder
    private var titleSettings: some View {
        Section {
            Picker("Shorten", selection: $truncationStyle) {
                ForEach(TruncationStyle.allCases) { style in
                    Text(style.title).tag(style.rawValue)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Max length").frame(width: 120, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { Double(maxLength) },
                        set: { maxLength = Int($0) }
                    ),
                    in: 0...120,
                    step: 1
                )
                Text(maxLength == 0 ? "Off" : "\(maxLength)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }

            Toggle("Scroll long titles", isOn: $scrollTitles)
            Toggle("Shrink text to fit", isOn: $autoScale)
            Toggle("Hide while a menu bar menu is open", isOn: $hideOnMenuOpen)
            Toggle("Strip browser and profile names", isOn: $stripBrowserNames)
        } header: {
            Text("Long titles")
        } footer: {
            Text("Max length counts characters and applies when scrolling is off. Scrolling moves a title that is wider than the space available. Shrink text to fit reduces the font size before shortening.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var position: some View {
        Section {
            sliderRow("Gap after menus", value: $gap, range: 0...40, unit: "pt")
            sliderRow("Left inset", value: $leftInset, range: 0...600, unit: "pt")
            sliderRow("Max width", value: $maxWidth, range: 80...800, unit: "pt")
        } header: {
            Text("Automatic placement")
        } footer: {
            Text("The title follows the front app's menus. It is shortened when the menu bar has no room.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var general: some View {
        Section {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { enabled in
                    launchAtLogin = enabled
                    if let message = LaunchAtLogin.set(enabled) {
                        loginError = message
                        launchAtLogin = LaunchAtLogin.isEnabled
                    } else {
                        loginError = nil
                    }
                    loginNeedsApproval = LaunchAtLogin.needsApproval
                }
            ))

            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }

            if loginNeedsApproval {
                Text("Approve MenuTitle in System Settings > General > Login Items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            HStack {
                Text("yabai")
                Spacer()
                Text(Yabai.path ?? "Not found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Quit MenuTitle") {
                NSApp.terminate(nil)
            }
        }
    }

    @ViewBuilder
    private var permissions: some View {
        Section {
            HStack(spacing: 8) {
                Circle()
                    .fill(accessibilityTrusted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(accessibilityTrusted ? "Accessibility access granted" : "Accessibility access required")
                Spacer()
                if !accessibilityTrusted {
                    Button("Grant…") {
                        grantAccessibility()
                    }
                }
            }

            Text("MenuTitle reads the front app's menu bar so the title stays clear of the menus. Positioning pauses until access is granted.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Permissions")
        }
    }

    private func fontDescription(_ family: String, _ traits: Int) -> String {
        let mask = NSFontTraitMask(rawValue: UInt(traits))
        var parts: [String] = []
        if mask.contains(.boldFontMask) { parts.append("Bold") }
        if mask.contains(.italicFontMask) { parts.append("Italic") }
        let base = family.isEmpty ? "System" : family
        return parts.isEmpty ? base : "\(base) \(parts.joined(separator: " "))"
    }

    private func grantAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // Privacy & Security pane. The Accessibility anchor works on macOS 26
        // and on macOS 27, where the pane includes Device Control and Data Access.
        let targets = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for target in targets {
            if let url = URL(string: target), NSWorkspace.shared.open(url) { break }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.systempreferences")
                .first?
                .activate(options: [.activateAllWindows])
        }
    }

    private func sliderRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        unit: String
    ) -> some View {
        HStack {
            Text(label).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(step < 1 ? String(format: "%.1f %@", value.wrappedValue, unit) : "\(Int(value.wrappedValue)) \(unit)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }
}
