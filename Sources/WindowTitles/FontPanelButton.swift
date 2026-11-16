import AppKit
import SwiftUI

/// A button that opens the system font panel and writes the chosen family,
/// size, and traits back to the given bindings.
struct FontPanelButton: NSViewRepresentable {
    @Binding var family: String
    @Binding var size: Double
    @Binding var traits: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            title: "Choose…",
            target: context.coordinator,
            action: #selector(Coordinator.open(_:))
        )
        button.bezelStyle = .rounded
        button.controlSize = .small
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ nsView: NSButton, coordinator: Coordinator) {
        if NSFontManager.shared.target === coordinator {
            NSFontManager.shared.target = nil
        }
    }

    final class Coordinator: NSObject {
        var parent: FontPanelButton

        init(_ parent: FontPanelButton) {
            self.parent = parent
        }

        @objc func open(_ sender: Any?) {
            let manager = NSFontManager.shared
            manager.target = self
            manager.action = #selector(changeFont(_:))
            manager.orderFrontFontPanel(sender)
            manager.setSelectedFont(currentFont(), isMultiple: false)
        }

        @objc private func changeFont(_ sender: NSFontManager) {
            let font = sender.convert(currentFont())
            parent.family = font.familyName ?? parent.family
            parent.size = min(18, max(8, Double(font.pointSize)))
            parent.traits = Int(sender.traits(of: font).rawValue)
        }

        private func currentFont() -> NSFont {
            FontResolver.font(family: parent.family, size: parent.size, traits: parent.traits)
        }
    }
}
