import AppKit

struct BarContent {
    var title: String
    var font: NSFont
    var color: NSColor
    var icon: NSImage?
    var glyph: NSAttributedString?
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
            if oldValue?.title != content?.title || oldValue?.scrolling != content?.scrolling {
                scrollOffset = 0
            }
            if oldValue?.scrollSpeed != content?.scrollSpeed {
                scrollTimer?.invalidate()
                scrollTimer = nil
            }
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

    private var scrollTimer: Timer?
    private var scrollOffset: CGFloat = 0

    deinit {
        scrollTimer?.invalidate()
    }

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
        min(18, height - 8)
    }

    private func iconWidth(forHeight height: CGFloat) -> CGFloat {
        guard let content else { return 0 }
        if content.icon != nil { return iconHeight(forHeight: height) }
        if let glyph = content.glyph { return glyph.size().width }
        return 0
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateScrolling()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateScrolling()
    }

    private func updateScrolling() {
        guard let content else { return }
        let overflows = naturalWidth(forHeight: bounds.height) > bounds.width + 1
        let shouldScroll = content.scrolling && overflows && window?.isVisible == true

        guard shouldScroll else {
            scrollTimer?.invalidate()
            scrollTimer = nil
            if scrollOffset != 0 {
                scrollOffset = 0
                needsDisplay = true
            }
            return
        }
        guard scrollTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            guard let self, let content = self.content, self.window?.isVisible == true else { return }
            self.scrollOffset += content.scrollSpeed / 24.0
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
    }

    func resumeScrolling() {
        updateScrolling()
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

        let available = max(0, bounds.width - x - content.paddingRight)
        let textRect = NSRect(x: x, y: 0, width: available, height: bounds.height)

        if content.scrolling {
            drawScrolling(styledTitle(content.title, content: content), in: textRect, offsetY: offsetY)
        } else {
            let text = truncated(content.title, content: content, width: available)
            let styled = styledTitle(text, content: content)
            let size = styled.size()
            styled.draw(at: NSPoint(
                x: x,
                y: (bounds.height - size.height) / 2 + offsetY
            ))
        }
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

    private func drawScrolling(_ text: NSAttributedString, in rect: NSRect, offsetY: CGFloat) {
        let size = text.size()
        let y = (rect.height - size.height) / 2 + offsetY

        guard size.width > rect.width else {
            text.draw(at: NSPoint(x: rect.minX, y: y))
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()

        let loop = size.width + 24
        let offset = scrollOffset.truncatingRemainder(dividingBy: loop)
        var drawX = rect.minX - offset
        while drawX < rect.maxX {
            text.draw(at: NSPoint(x: drawX, y: y))
            drawX += loop
        }

        NSGraphicsContext.restoreGraphicsState()
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
