import AppKit
import ApplicationServices
import SwiftUI

struct SettingsView: View {
    @AppStorage(Pref.fontFamily) private var fontFamily = "Liga SFMono Nerd Font"
    @AppStorage(Pref.fontSize) private var fontSize = 11.0
    @AppStorage(Pref.padding) private var padding = 8.0
    @AppStorage(Pref.letterSpacing) private var letterSpacing = 0.0
    @AppStorage(Pref.wordSpacing) private var wordSpacing = 0.0
    @AppStorage(Pref.gap) private var gap = 6.0
    @AppStorage(Pref.leftInset) private var leftInset = 0.0
    @AppStorage(Pref.maxWidth) private var maxWidth = 360.0
    @AppStorage(Pref.iconStyle) private var iconStyle = IconStyle.appFont.rawValue
    @AppStorage(Pref.backgroundStyle) private var backgroundStyle = BarBackgroundStyle.liquidGlass.rawValue
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
    @AppStorage(Pref.customPosition) private var customPosition = false
    @AppStorage(Pref.lockPosition) private var lockPosition = false

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?
    @State private var loginNeedsApproval = LaunchAtLogin.needsApproval
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    private var fontFamilies: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }

    private var previewFont: Font {
        fontFamily.isEmpty ? .system(size: fontSize) : .custom(fontFamily, size: fontSize)
    }

    var body: some View {
        Form {
            Section {
                Picker("Next to the title", selection: $iconStyle) {
                    ForEach(IconStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }

                Picker("Font", selection: $fontFamily) {
                    Text("System").tag("")
                    ForEach(fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }

                Picker("Background", selection: $backgroundStyle) {
                    ForEach(BarBackgroundStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }

                sliderRow("Size", value: $fontSize, range: 8...18, unit: "pt")
                sliderRow("Padding", value: $padding, range: 0...24, unit: "pt")
                sliderRow("Letter spacing", value: $letterSpacing, range: -1...5, step: 0.5, unit: "pt")
                sliderRow("Word spacing", value: $wordSpacing, range: 0...12, unit: "pt")

                HStack {
                    Spacer()
                    Text("Window Title").font(previewFont).foregroundStyle(.secondary)
                    Spacer()
                }
            } header: {
                Text("Appearance")
            } footer: {
                if iconStyle == IconStyle.appFont.rawValue && !AppIconFont.shared.loaded {
                    Text("sketchybar-app-font.ttf was not found in ~/Library/Fonts or /Library/Fonts. Choose another icon style or install the font.")
                }
            }

            Section {
                Toggle("Show title bar", isOn: $showPanel)
                Toggle("Show menu bar item", isOn: $showStatusItem)
                Toggle("Use custom position", isOn: $customPosition)
                if customPosition {
                    Toggle("Lock position", isOn: $lockPosition)
                    Text("Drag the title to move it. The position is remembered.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Placement")
            } footer: {
                Text("The menu bar item uses the same title, icon, and click settings.")
            }

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
                Text("Clicking")
            } footer: {
                Text("App actions apply to the app that owns the shown window.")
            }

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
                Text("Title")
            } footer: {
                Text("Max length counts characters and applies when scrolling is off. Scrolling moves a title that is wider than the space available. Shrink text to fit reduces the font size before shortening.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                sliderRow("Gap after menus", value: $gap, range: 0...40, unit: "pt")
                sliderRow("Left inset", value: $leftInset, range: 0...600, unit: "pt")
                sliderRow("Max width", value: $maxWidth, range: 80...800, unit: "pt")
            } header: {
                Text("Position")
            } footer: {
                Text("The title follows the front app's menus. It is shortened when the menu bar has no room.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
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
                    Text("Approve Window Titles in System Settings > General > Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("yabai")
                    Spacer()
                    Text(Yabai.path ?? "Not found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Quit Window Titles") {
                    NSApp.terminate(nil)
                }
            }

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

                Text("Window Titles reads the front app's menu bar so the title stays clear of the menus. Positioning pauses until access is granted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 760)
        .onAppear {
            accessibilityTrusted = AXIsProcessTrusted()
            launchAtLogin = LaunchAtLogin.isEnabled
            loginNeedsApproval = LaunchAtLogin.needsApproval
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = AXIsProcessTrusted()
        }
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
