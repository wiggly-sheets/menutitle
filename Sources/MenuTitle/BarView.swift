import AppKit
import QuartzCore

struct BarContent {
    var title: String
    var font: NSFont
    var color: NSColor
    var icon: NSImage?
    var glyph: NSAttributedString?
    var iconSize: CGFloat
    var paddingLeft: CGFloat
    var paddingRight: CGFloat
    var paddingTop: CGFloat
    var paddingBottom: CGFloat
    var spacing: CGFloat
    var letterSpacing: CGFloat
    var wordSpacing: CGFloat
    var truncation: TruncationStyle
    var scrolling: Bool
    var scrollSpeed: CGFloat
    var background: BarBackgroundStyle
    var backgroundColor: NSColor?
    var backgroundOpacity: CGFloat
    var cornerRadius: CGFloat
    var backgroundInsetY: CGFloat
}

final class BarView: NSView {
    var content: BarContent? {
        didSet {
            stopScrolling()
            needsDisplay = true
            updateScrolling()
        }
    }
    var onLeftClick: (() -> Void)?
    var onMiddleClick: (() -> Void)?
    var onRightClick: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?
    var isDraggable = false
    private(set) var isDragging = false
    private var mouseStart: NSPoint?
    private var originStart: NSPoint?
    private var isPressed = false {
        didSet {
            if oldValue != isPressed { needsDisplay = true }
        }
    }
    private var pressReset: DispatchWorkItem?

    private var scrollClip: NSView?

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func naturalWidth(forHeight height: CGFloat) -> CGFloat {
        guard let content else { return 0 }
        let titleWidth = styledTitle(content.title, content: content).size().width
        let iconWidth = self.iconWidth(forHeight: height)
        return content.paddingLeft + content.paddingRight + iconWidth
            + (iconWidth > 0 ? content.spacing : 0) + titleWidth
    }

    private func iconHeight(forHeight height: CGFloat) -> CGFloat {
        guard let content else { return 0 }
        return min(content.iconSize, height - 8)
    }

    private func iconWidth(forHeight height: CGFloat) -> CGFloat {
        guard let content else { return 0 }
        if content.icon != nil { return iconHeight(forHeight: height) }
        if let glyph = content.glyph { return glyph.size().width }
        return 0
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        stopScrolling()
        updateScrolling()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopScrolling()
        updateScrolling()
    }

    private func updateScrolling() {
        guard let content else { return }
        let rect = textRect(for: content)
        let text = styledTitle(content.title, content: content)

        guard content.scrolling, text.size().width > rect.width + 1,
              window?.isVisible == true else {
            pauseScrolling()
            return
        }
        guard scrollClip == nil else { return }

        // Animate the strip's layer: a scrolling frame costs no drawing.
        let gap: CGFloat = 24
        let loop = text.size().width + gap
        let textHeight = text.size().height
        let image = NSImage(
            size: NSSize(width: loop * 2, height: textHeight),
            flipped: true
        ) { _ in
            text.draw(at: .zero)
            text.draw(at: NSPoint(x: loop, y: 0))
            return true
        }

        let clip = NSView(frame: rect)
        clip.wantsLayer = true
        clip.layer?.masksToBounds = true
        addSubview(clip)

        let strip = NSImageView(frame: NSRect(
            x: 0,
            y: (rect.height - textHeight) / 2 + contentVerticalOffset(for: content),
            width: loop * 2,
            height: textHeight
        ))
        strip.wantsLayer = true
        strip.image = image
        strip.imageScaling = .scaleNone
        clip.addSubview(strip)

        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -loop
        animation.duration = CFTimeInterval(loop / max(content.scrollSpeed, 1))
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        strip.layer?.add(animation, forKey: "scroll")

        scrollClip = clip
    }

    private func stopScrolling() {
        scrollClip?.removeFromSuperview()
        scrollClip = nil
    }

    func resumeScrolling() {
        updateScrolling()
    }

    func pauseScrolling() {
        guard scrollClip != nil else { return }
        stopScrolling()
        needsDisplay = true
    }

    func cancelInteraction() {
        isDragging = false
        isPressed = false
        mouseStart = nil
        originStart = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let content else { return }

        drawBackground(content)
        if isPressed { drawHighlight(content) }

        let offsetY = contentVerticalOffset(for: content)
        var x = content.paddingLeft
        if let icon = content.icon {
            let side = iconHeight(forHeight: bounds.height)
            icon.draw(in: NSRect(
                x: x,
                y: (bounds.height - side) / 2 + offsetY,
                width: side,
                height: side
            ))
            x += side + content.spacing
        } else if let glyph = content.glyph {
            let size = glyph.size()
            glyph.draw(at: NSPoint(
                x: x,
                y: (bounds.height - size.height) / 2 + offsetY
            ))
            x += size.width + content.spacing
        }

        let textRect = self.textRect(for: content)

        if content.scrolling {
            if scrollClip == nil {
                drawTitle(styledTitle(content.title, content: content), in: textRect, offsetY: offsetY)
            }
        } else {
            let title = truncated(content.title, content: content, width: textRect.width)
            drawTitle(styledTitle(title, content: content), in: textRect, offsetY: offsetY)
        }
    }

    private func textRect(for content: BarContent) -> NSRect {
        let icon = iconWidth(forHeight: bounds.height)
        let x = content.paddingLeft + icon + (icon > 0 ? content.spacing : 0)
        return NSRect(
            x: x,
            y: 0,
            width: max(0, bounds.width - x - content.paddingRight),
            height: bounds.height
        )
    }

    private func drawTitle(_ text: NSAttributedString, in rect: NSRect, offsetY: CGFloat) {
        let size = text.size()
        text.draw(at: NSPoint(x: rect.minX, y: (rect.height - size.height) / 2 + offsetY))
    }

    private func styledTitle(_ text: String, content: BarContent) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: content.font,
                .foregroundColor: content.color,
                .kern: content.letterSpacing,
            ]
        )
        guard content.wordSpacing != 0 else { return attributed }

        let ns = text as NSString
        var location = 0
        while location < ns.length {
            let range = ns.range(
                of: " ",
                options: [],
                range: NSRange(location: location, length: ns.length - location)
            )
            guard range.location != NSNotFound else { break }
            attributed.addAttribute(.kern, value: content.letterSpacing + content.wordSpacing, range: range)
            location = range.location + range.length
        }
        return attributed
    }

    private func verticalPadding(_ content: BarContent) -> (top: CGFloat, bottom: CGFloat) {
        (
            top: max(0, content.paddingTop - content.backgroundInsetY),
            bottom: max(0, content.paddingBottom - content.backgroundInsetY)
        )
    }

    private func contentHeight(for content: BarContent, height: CGFloat) -> CGFloat {
        let titleHeight = content.font.ascender - content.font.descender + content.font.leading
        if content.icon != nil || content.glyph != nil {
            return max(titleHeight, iconHeight(forHeight: height))
        }
        return titleHeight
    }

    func backgroundInsetY(for content: BarContent, height: CGFloat) -> CGFloat {
        let padding = verticalPadding(content)
        let backgroundHeight = min(
            height - 1,
            contentHeight(for: content, height: height) + padding.top + padding.bottom
        )
        return max(0, (height - backgroundHeight) / 2)
    }

    private func contentVerticalOffset(for content: BarContent) -> CGFloat {
        let padding = verticalPadding(content)
        let limit = max(0, (bounds.height - contentHeight(for: content, height: bounds.height)) / 2)
        return min(limit, max(-limit, (padding.bottom - padding.top) / 2))
    }

    private func backgroundRect(for content: BarContent) -> NSRect {
        let insetY = backgroundInsetY(for: content, height: bounds.height)
        return bounds.insetBy(dx: 0.5, dy: insetY + 0.5)
    }

    private func drawHighlight(_ content: BarContent) {
        let rect = backgroundRect(for: content)
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(content.cornerRadius, rect.height / 2)
        NSColor.labelColor.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    private func drawBackground(_ content: BarContent) {
        guard content.background == .solid || content.background == .outline else { return }
        let rect = backgroundRect(for: content)
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(content.cornerRadius, rect.height / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        switch content.background {
        case .solid:
            (content.backgroundColor ?? .windowBackgroundColor)
                .withAlphaComponent(content.backgroundOpacity)
                .setFill()
            path.fill()
        case .outline:
            (content.backgroundColor ?? .separatorColor)
                .withAlphaComponent(content.backgroundOpacity)
                .setStroke()
            path.lineWidth = 1
            path.stroke()
        case .liquidGlass, .transparent:
            break
        }
    }

    private func truncated(_ text: String, content: BarContent, width: CGFloat) -> String {
        guard width > 0 else { return "" }
        if styledTitle(text, content: content).size().width <= width { return text }

        let characters = Array(text)
        let ellipsis = "…"
        var low = 0
        var high = characters.count
        var best = ellipsis

        while low <= high {
            let middle = (low + high) / 2
            let headCount = (middle + 1) / 2
            let tailCount = middle / 2
            let candidate: String
            switch content.truncation {
            case .end:
                candidate = String(characters[0..<middle]) + ellipsis
            case .beginning:
                candidate = ellipsis + String(characters[(characters.count - middle)...])
            case .middle:
                candidate = String(characters[0..<headCount]) + ellipsis
                    + String(characters[(characters.count - tailCount)...])
            }

            if styledTitle(candidate, content: content).size().width <= width {
                best = candidate
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return best
    }

    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation
        originStart = window?.frame.origin
        isDragging = false
        isPressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggable, let mouseStart, let originStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - mouseStart.x
        let dy = now.y - mouseStart.y
        if abs(dx) > 3 || abs(dy) > 3 { isDragging = true }
        guard isDragging else { return }
        isPressed = false
        window.setFrameOrigin(NSPoint(x: originStart.x + dx, y: originStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            isPressed = false
            isDragging = false
            mouseStart = nil
            originStart = nil
        }
        if isDragging, let origin = window?.frame.origin {
            onDragEnd?(origin)
        } else {
            onLeftClick?()
        }
    }

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 {
            flashPress()
            onMiddleClick?()
        } else {
            super.otherMouseDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        isPressed = true
        onRightClick?(convert(event.locationInWindow, from: nil))
        isPressed = false
    }

    private func flashPress() {
        isPressed = true
        pressReset?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.isPressed = false }
        pressReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}
