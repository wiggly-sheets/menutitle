import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let bar = BarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: Pref.defaults)

        DispatchQueue.global(qos: .userInitiated).async {
            let available = Yabai.isAvailable()
            DispatchQueue.main.async {
                guard available else {
                    self.showYabaiAlert()
                    return
                }
                Permissions.showMissingAlertIfNeeded()
                AppFontUpdater.startBackground()
                self.bar.start()
            }
        }
    }

    private func showYabaiAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MenuTitle needs yabai"
        alert.informativeText = """
            MenuTitle reads the focused window from yabai. Install yabai with Homebrew, \
            then open MenuTitle again.
            """
        alert.addButton(withTitle: "Install yabai")
        alert.addButton(withTitle: "Quit")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "https://github.com/koekeishiya/yabai") {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return true
    }
}
