import AppKit
import SwiftUI

final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "MenuTitle"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 680, height: 520)
            let hosting = NSHostingView(rootView: SettingsView())
            hosting.frame = window.contentView?.bounds ?? .zero
            hosting.autoresizingMask = [.width, .height]
            window.contentView?.addSubview(hosting)
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
