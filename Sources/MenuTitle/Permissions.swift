import AppKit

enum Permissions {
    private static var didShowMissingAlert = false

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Privacy & Security pane. The Accessibility anchor works on macOS 26 and
    /// on macOS 27, where the pane includes Device Control and Data Access.
    static func openAccessibilitySettings() {
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

    static func requestAndOpen() {
        requestAccessibility()
        openAccessibilitySettings()
    }

    static func showMissingAlertIfNeeded() {
        guard !hasAccessibility, !didShowMissingAlert else { return }
        didShowMissingAlert = true

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MenuTitle needs Accessibility access"
        alert.informativeText = """
            MenuTitle reads window titles and measures the menu bar through Accessibility. \
            The floating title and the menu bar item stay hidden until you grant access in \
            System Settings > Privacy & Security > Accessibility.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            requestAndOpen()
        }
    }
}
