import AppKit

final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var onAction: ((Int) -> Void)?

    override init() {
        super.init()
        item.isVisible = false
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])
    }

    var anchorView: NSView? { item.button }

    var menuPoint: NSPoint {
        NSPoint(x: 0, y: item.button?.bounds.height ?? 0)
    }

    func update(_ content: BarContent?) {
        guard let content else {
            item.isVisible = false
            return
        }
        item.isVisible = true
        guard let button = item.button else { return }

        let title = NSMutableAttributedString()
        if let glyph = content.glyph {
            title.append(glyph)
            title.append(NSAttributedString(string: " "))
        }
        var attributes: [NSAttributedString.Key: Any] = [
            .font: content.font,
            .foregroundColor: content.color,
        ]
        if content.letterSpacing != 0 {
            attributes[.kern] = content.letterSpacing
        }
        title.append(NSAttributedString(string: content.title, attributes: attributes))

        button.attributedTitle = title
        button.image = content.icon
        button.imagePosition = content.icon == nil ? .noImage : .imageLeading
    }

    @objc private func clicked() {
        onAction?(NSApp.currentEvent?.buttonNumber ?? 0)
    }
}
