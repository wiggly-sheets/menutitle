import AppKit

final class BarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // The menu bar area is excluded from normal window placement.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class BarController: NSObject {
    private var panel: BarPanel
    private let container = NSView()
    private let view = BarView()
    private var glassHost: NSView?
    private let queue = DispatchQueue(label: "com.wigglysheets.menutitle.query")
    private let statusItem = StatusItemController()
    private var currentInfo: FrontWindowInfo?
    private var timer: Timer?
    private var menuTimer: Timer?
    private var menuOpen = false
    private let observer = FrontWindowObserver()
    private var refreshWork: DispatchWorkItem?
    private var lastRenderKey: String?
    private var busy = false
    private var pending = false
    private var lastFrontPid: pid_t?
    private var settleDeadline = Date.distantPast
    private var retryCount = 0
    private var lastPanelRebuild = Date.distantPast

    override init() {
        panel = BarPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel(panel)

        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
        panel.contentView = container

        view.onLeftClick = { [weak self] in self?.performClick(button: 0) }
        view.onMiddleClick = { [weak self] in self?.performClick(button: 2) }
        view.onRightClick = { [weak self] point in self?.performClick(button: 1, panelPoint: point) }
        view.onDragEnd = { [weak self] origin in self?.savePosition(origin) }
        statusItem.onAction = { [weak self] number in self?.performStatusClick(button: number) }
    }

    private func configurePanel(_ target: BarPanel) {
        target.isFloatingPanel = true
        target.level = .statusBar
        target.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        target.hidesOnDeactivate = false
        target.isOpaque = false
        target.backgroundColor = .clear
        target.hasShadow = false
        target.animationBehavior = .none
    }

    // Sleep, wake, and login screen switching can strand the panel on a Space
    // that no longer exists. Only a new window is placed on the active Space.
    private func rebuildPanel() {
        guard Date().timeIntervalSince(lastPanelRebuild) > 1 else { return }
        lastPanelRebuild = Date()
        let wasVisible = panel.isVisible
        let old = panel
        let replacement = BarPanel(
            contentRect: old.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel(replacement)
        replacement.contentView = container
        panel = replacement
        old.contentView = nil
        old.orderOut(nil)
        lastRenderKey = nil
        if wasVisible {
            replacement.alphaValue = 0
            replacement.orderFrontRegardless()
            scheduleRefresh(after: 0.05)
        }
    }

    private func ensureOnActiveSpace() {
        guard panel.isVisible, !panel.isOnActiveSpace else { return }
        rebuildPanel()
    }

    @objc private func systemDidWake() {
        observer.stop()
        view.cancelInteraction()
        lastFrontPid = nil
        lastRenderKey = nil
        retryCount = 0
        settleDeadline = .distantPast
        rebuildPanel()
        scheduleRefresh(after: 0.5)
    }

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refresh),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appFontChanged),
            name: AppIconFont.didChangeNotification,
            object: nil
        )
        for name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(systemDidWake),
                name: name,
                object: nil
            )
        }

        observer.start { [weak self] in self?.scheduleRefresh() }

        refresh()
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer

        let menuTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateMenuState()
        }
        RunLoop.main.add(menuTimer, forMode: .common)
        self.menuTimer = menuTimer
    }

    @objc private func appFontChanged() {
        lastRenderKey = nil
        refresh()
    }

    private func scheduleRefresh(after delay: TimeInterval = 0.05) {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
    }

    private func updateMenuState() {
        ensureOnActiveSpace()
        let frontPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let hides = UserDefaults.standard.bool(forKey: Pref.hideOnMenuOpen)
        let range = panel.frame.width > 1
            ? panel.frame.minX...panel.frame.maxX
            : nil
        let open = hides && MenuBarGeometry.hasOpenMenu(pid: frontPid, overlappingX: range)
        let hidden = open || MenuBarGeometry.isMissionControlActive()
        guard hidden != menuOpen else { return }
        menuOpen = hidden
        if hidden {
            hide()
        } else {
            refresh()
        }
    }

    @objc func refresh() {
        guard AXIsProcessTrusted() else {
            lastFrontPid = nil
            hide()
            statusItem.update(nil)
            return
        }

        let frontmost = NSWorkspace.shared.frontmostApplication
        guard let frontPid = frontmost?.processIdentifier,
              frontPid != ProcessInfo.processInfo.processIdentifier else {
            lastFrontPid = nil
            hide()
            statusItem.update(nil)
            return
        }

        if frontPid != lastFrontPid {
            lastFrontPid = frontPid
            retryCount = 0
            // The menu bar still shows the previous app's menus for a moment.
            settleDeadline = Date().addingTimeInterval(0.18)
            hide()
        }

        let remaining = settleDeadline.timeIntervalSinceNow
        if remaining > 0 {
            scheduleRefresh(after: remaining)
            return
        }

        if busy {
            pending = true
            return
        }
        busy = true
        observer.observe(pid: frontPid)

        queue.async { [weak self] in
            let info = Yabai.queryFrontWindow()
            let menuBar = MenuBarGeometry.menuBar(pid: frontPid)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                let sameApp = NSWorkspace.shared.frontmostApplication?.processIdentifier == frontPid
                let missing = info == nil || menuBar == nil || (info?.title.isEmpty ?? true)
                if sameApp, missing, self.retryCount < 2 {
                    self.retryCount += 1
                    self.scheduleRefresh(after: 0.12)
                    return
                }
                if sameApp {
                    self.retryCount = 0
                    self.apply(info: info, menuBar: menuBar)
                }
                if self.pending {
                    self.pending = false
                    self.refresh()
                }
            }
        }
    }

    private func apply(info: FrontWindowInfo?, menuBar: MenuBarGeometry.MenuBar?) {
        let defaults = UserDefaults.standard
        guard let info,
              !info.title.isEmpty,
              !info.fullscreen,
              let menuBar,
              let screen = MenuBarGeometry.screen(forAXPoint: menuBar.anchor) else {
            hide()
            statusItem.update(nil)
            return
        }

        var keyParts: [String] = [
            info.app, info.title, String(info.pid), String(info.fullscreen),
            "\(menuBar.endX)", "\(menuBar.anchor.x)", "\(menuBar.anchor.y)", String(describing: screen.frame),
            String(menuOpen),
            defaults.string(forKey: Pref.fontFamily) ?? "",
            String(defaults.integer(forKey: Pref.fontTraits)),
            String(defaults.double(forKey: Pref.fontSize)),
            String(defaults.double(forKey: Pref.padding)),
            "\(defaults.bool(forKey: Pref.paddingLinked))",
            String(defaults.double(forKey: Pref.paddingLeft)),
            String(defaults.double(forKey: Pref.paddingRight)),
            String(defaults.double(forKey: Pref.paddingTop)),
            String(defaults.double(forKey: Pref.paddingBottom)),
            String(defaults.double(forKey: Pref.letterSpacing)),
            String(defaults.double(forKey: Pref.wordSpacing)),
            defaults.string(forKey: Pref.iconStyle) ?? "",
            defaults.string(forKey: Pref.backgroundStyle) ?? "",
            "\(defaults.bool(forKey: Pref.useCustomTextColor))",
            defaults.string(forKey: Pref.textColorHex) ?? "",
            "\(defaults.bool(forKey: Pref.useCustomBackgroundColor))",
            defaults.string(forKey: Pref.backgroundColorHex) ?? "",
            String(defaults.double(forKey: Pref.backgroundOpacity)),
            String(defaults.double(forKey: Pref.backgroundCornerRadius)),
            String(defaults.double(forKey: Pref.backgroundInsetY)),
            defaults.string(forKey: Pref.truncationStyle) ?? "",
            String(defaults.integer(forKey: Pref.maxLength)),
            "\(defaults.bool(forKey: Pref.scrollTitles))",
            String(defaults.double(forKey: Pref.scrollSpeed)),
        ]
        keyParts += [
            "\(defaults.bool(forKey: Pref.autoScale))",
            "\(defaults.bool(forKey: Pref.stripBrowserNames))",
            defaults.string(forKey: Pref.customBrowserSuffixes) ?? "",
            String(defaults.double(forKey: Pref.gap)),
            String(defaults.double(forKey: Pref.leftInset)),
            String(defaults.double(forKey: Pref.maxWidth)),
            "\(defaults.bool(forKey: Pref.showPanel))",
            "\(defaults.bool(forKey: Pref.showStatusItem))",
            "\(defaults.bool(forKey: Pref.customPosition))",
            "\(defaults.bool(forKey: Pref.lockPosition))",
            displayKey(screen),
            savedPosition(for: screen).map { "\($0.x),\($0.y)" } ?? "",
            "\(defaults.bool(forKey: Pref.statusItemMirrorsTitle))",
            defaults.string(forKey: Pref.statusItemIconStyle) ?? "",
            defaults.string(forKey: Pref.statusItemFontFamily) ?? "",
            String(defaults.integer(forKey: Pref.statusItemFontTraits)),
            String(defaults.double(forKey: Pref.statusItemFontSize)),
        ]
        let key = keyParts.joined(separator: "\u{1}")

        guard key != lastRenderKey || !panel.isVisible || panel.alphaValue < 1 else { return }
        lastRenderKey = key
        currentInfo = info

        let showPanel = defaults.bool(forKey: Pref.showPanel)
        let showStatusItem = defaults.bool(forKey: Pref.showStatusItem)
        let customPosition = defaults.bool(forKey: Pref.customPosition)
        let lockPosition = defaults.bool(forKey: Pref.lockPosition)

        let barHeight = MenuBarGeometry.height(for: screen)
        let fontSize = CGFloat(defaults.double(forKey: Pref.fontSize))
        let fontFamily = defaults.string(forKey: Pref.fontFamily) ?? ""
        let fontTraits = defaults.integer(forKey: Pref.fontTraits)
        let iconStyle = IconStyle(rawValue: defaults.string(forKey: Pref.iconStyle) ?? "") ?? .appFont
        let padding = CGFloat(defaults.double(forKey: Pref.padding))
        let paddingLinked = defaults.bool(forKey: Pref.paddingLinked)
        let paddingLeft = paddingLinked ? padding : CGFloat(defaults.double(forKey: Pref.paddingLeft))
        let paddingRight = paddingLinked ? padding : CGFloat(defaults.double(forKey: Pref.paddingRight))
        let paddingTop = paddingLinked ? padding : CGFloat(defaults.double(forKey: Pref.paddingTop))
        let paddingBottom = paddingLinked ? padding : CGFloat(defaults.double(forKey: Pref.paddingBottom))
        let letterSpacing = CGFloat(defaults.double(forKey: Pref.letterSpacing))
        let wordSpacing = CGFloat(defaults.double(forKey: Pref.wordSpacing))
        let gap = CGFloat(defaults.double(forKey: Pref.gap))
        let inset = CGFloat(defaults.double(forKey: Pref.leftInset))
        let maxWidth = CGFloat(defaults.double(forKey: Pref.maxWidth))
        let truncation = TruncationStyle(rawValue: defaults.string(forKey: Pref.truncationStyle) ?? "") ?? .end
        let background = BarBackgroundStyle(rawValue: defaults.string(forKey: Pref.backgroundStyle) ?? "") ?? .liquidGlass
        let textColor = defaults.bool(forKey: Pref.useCustomTextColor)
            ? (NSColor(hex: defaults.string(forKey: Pref.textColorHex) ?? "") ?? .labelColor)
            : .labelColor
        let backgroundColor = defaults.bool(forKey: Pref.useCustomBackgroundColor)
            ? NSColor(hex: defaults.string(forKey: Pref.backgroundColorHex) ?? "")
            : nil
        let backgroundOpacity = CGFloat(defaults.double(forKey: Pref.backgroundOpacity))
        let cornerRadius = CGFloat(defaults.double(forKey: Pref.backgroundCornerRadius))
        let backgroundInsetY = CGFloat(defaults.double(forKey: Pref.backgroundInsetY))
        let scrolling = defaults.bool(forKey: Pref.scrollTitles)
        let scrollSpeed = CGFloat(defaults.double(forKey: Pref.scrollSpeed))

        let browserContext = BrowserDetector.context(
            appName: info.app,
            pid: info.pid,
            customSuffixesText: defaults.string(forKey: Pref.customBrowserSuffixes) ?? ""
        )
        let cleanedTitle = TitleCleaner.clean(
            info.title,
            stripBrowserNames: defaults.bool(forKey: Pref.stripBrowserNames),
            context: browserContext
        )
        let title = scrolling
            ? cleanedTitle
            : TitleCleaner.truncate(cleanedTitle, maxLength: defaults.integer(forKey: Pref.maxLength), style: truncation)

        let x = max(menuBar.endX + gap + inset, screen.frame.minX + 2)
        var cap = maxWidth
        if customPosition {
            cap = min(cap, screen.frame.width - 4)
        } else {
            if let notch = MenuBarGeometry.notchLeftX(for: screen), x < notch {
                cap = min(cap, notch - x - gap)
            }
            if let limit = MenuBarGeometry.leftmostObstructionX(
                screen: screen,
                barHeight: barHeight,
                afterX: x,
                excludingPid: ProcessInfo.processInfo.processIdentifier
            ) {
                cap = min(cap, limit - x - gap)
            }
            cap = min(cap, screen.frame.maxX - x - 2)
        }
        guard cap >= 24 else {
            hide()
            return
        }

        func makeContent(_ size: CGFloat, _ family: String, _ traits: Int, _ style: IconStyle) -> BarContent {
            let font = FontResolver.font(family: family, size: size, traits: traits)
            var glyph: NSAttributedString?
            var icon: NSImage?
            switch style {
            case .none:
                break
            case .appFont:
                if let character = AppIconFont.shared.glyph(for: info.app) {
                    let iconFont = AppIconFont.shared.font(size: size + 3) ?? font
                    glyph = NSAttributedString(
                        string: character,
                        attributes: [.font: iconFont, .foregroundColor: textColor]
                    )
                }
            case .native:
                icon = NSRunningApplication(processIdentifier: info.pid)?.icon
            }
            return BarContent(
                title: title,
                font: font,
                color: textColor,
                icon: icon,
                glyph: glyph,
                paddingLeft: paddingLeft,
                paddingRight: paddingRight,
                paddingTop: paddingTop,
                paddingBottom: paddingBottom,
                spacing: 5,
                letterSpacing: letterSpacing,
                wordSpacing: wordSpacing,
                truncation: truncation,
                scrolling: scrolling,
                scrollSpeed: scrollSpeed,
                background: background,
                backgroundColor: backgroundColor,
                backgroundOpacity: backgroundOpacity,
                cornerRadius: cornerRadius,
                backgroundInsetY: backgroundInsetY
            )
        }

        let titleContent = makeContent(fontSize, fontFamily, fontTraits, iconStyle)
        var size = fontSize
        var content = titleContent
        view.content = content
        var natural = view.naturalWidth(forHeight: barHeight)

        if defaults.bool(forKey: Pref.autoScale) {
            let minimum = max(8, fontSize * 0.6)
            while natural > cap && size > minimum + 0.001 {
                size = max(minimum, size - 0.5)
                content = makeContent(size, fontFamily, fontTraits, iconStyle)
                view.content = content
                natural = view.naturalWidth(forHeight: barHeight)
            }
        }

        var statusContent: BarContent?
        if showStatusItem {
            if defaults.bool(forKey: Pref.statusItemMirrorsTitle) {
                statusContent = titleContent
            } else {
                let statusStyle = IconStyle(
                    rawValue: defaults.string(forKey: Pref.statusItemIconStyle) ?? ""
                ) ?? .appFont
                statusContent = makeContent(
                    CGFloat(defaults.double(forKey: Pref.statusItemFontSize)),
                    defaults.string(forKey: Pref.statusItemFontFamily) ?? "",
                    defaults.integer(forKey: Pref.statusItemFontTraits),
                    statusStyle
                )
            }
        }
        statusItem.update(statusContent)
        guard showPanel, !menuOpen else {
            hide()
            return
        }
        if view.isDragging { return }

        view.isDraggable = customPosition && !lockPosition
        let width = min(natural, cap)

        let frame: NSRect
        if customPosition {
            var origin: NSPoint
            if let saved = savedPosition(for: screen) {
                origin = saved
            } else {
                origin = NSPoint(x: x, y: screen.frame.maxY - barHeight)
                savePosition(origin, screen: screen)
            }
            let target = NSScreen.screens.first { $0.frame.contains(origin) } ?? screen
            origin.x = min(max(origin.x, target.frame.minX), target.frame.maxX - width)
            origin.y = min(max(origin.y, target.frame.minY), target.frame.maxY - barHeight)
            frame = NSRect(origin: origin, size: NSSize(width: width, height: barHeight))
        } else {
            frame = NSRect(
                x: x,
                y: screen.frame.maxY - barHeight,
                width: width,
                height: barHeight
            )
        }

        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        updateGlass(
            background == .liquidGlass,
            tint: backgroundColor,
            cornerRadius: cornerRadius,
            insetY: view.backgroundInsetY(for: content, height: barHeight)
        )
        view.needsDisplay = true
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            view.resumeScrolling()
        }
        if panel.alphaValue < 1 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    private func updateGlass(
        _ enabled: Bool,
        tint: NSColor?,
        cornerRadius: CGFloat,
        insetY: CGFloat
    ) {
        if enabled {
            if glassHost == nil {
                if #available(macOS 26.0, *) {
                    let glass = NSGlassEffectView()
                    glass.style = .regular
                    glass.cornerRadius = cornerRadius
                    glass.frame = container.bounds
                    container.addSubview(glass)
                    glassHost = glass
                } else {
                    let blur = NSVisualEffectView()
                    blur.material = .underWindowBackground
                    blur.blendingMode = .behindWindow
                    blur.state = .active
                    blur.wantsLayer = true
                    blur.layer?.cornerRadius = cornerRadius
                    blur.layer?.masksToBounds = true
                    blur.frame = container.bounds
                    container.addSubview(blur)
                    glassHost = blur
                }
            }
            guard let glassHost else { return }

            glassHost.frame = container.bounds.insetBy(dx: 0, dy: insetY)
            if #available(macOS 26.0, *), let glass = glassHost as? NSGlassEffectView {
                glass.cornerRadius = cornerRadius
                glass.tintColor = tint
            } else if let blur = glassHost as? NSVisualEffectView {
                blur.layer?.cornerRadius = cornerRadius
            }

            if view.superview !== glassHost {
                view.frame = glassHost.bounds
                view.autoresizingMask = [.width, .height]
                if #available(macOS 26.0, *), let glass = glassHost as? NSGlassEffectView {
                    glass.contentView = view
                } else {
                    glassHost.addSubview(view)
                }
            }
            view.frame = glassHost.bounds
            glassHost.isHidden = false
        } else {
            if view.superview !== container {
                view.frame = container.bounds
                view.autoresizingMask = [.width, .height]
                container.addSubview(view)
            }
            view.frame = container.bounds
            glassHost?.isHidden = true
        }
    }

    private func hide() {
        lastRenderKey = nil
        panel.alphaValue = 0
        if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private func clickAction(button: Int) -> ClickAction {
        let key: String
        switch button {
        case 0: key = Pref.leftClickAction
        case 1: key = Pref.rightClickAction
        case 2: key = Pref.middleClickAction
        default: return .none
        }
        return ClickAction(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .none
    }

    private func performClick(button: Int, panelPoint: NSPoint = .zero) {
        perform(clickAction(button: button), point: panelPoint, target: view)
    }

    private func performStatusClick(button: Int) {
        let defaults = UserDefaults.standard
        let action: ClickAction
        if defaults.bool(forKey: Pref.statusItemMirrorsClicks) {
            action = clickAction(button: button)
        } else {
            let key: String
            switch button {
            case 0: key = Pref.statusItemLeftClickAction
            case 1: key = Pref.statusItemRightClickAction
            case 2: key = Pref.statusItemMiddleClickAction
            default: return
            }
            action = ClickAction(rawValue: defaults.string(forKey: key) ?? "") ?? .none
        }
        perform(action, point: statusItem.menuPoint, target: statusItem.anchorView)
    }

    private func perform(_ action: ClickAction, point: NSPoint, target: NSView?) {
        switch action {
        case .none:
            return
        case .openSettings:
            SettingsWindow.shared.show()
        case .showMenu:
            if let target {
                showMenu(at: point, in: target)
            }
        case .focusApp:
            frontApp?.activate()
        case .hideApp:
            frontApp?.hide()
        case .minimizeApp:
            minimizeCurrentWindow()
        case .quitApp:
            frontApp?.terminate()
        }
    }

    private var frontApp: NSRunningApplication? {
        currentInfo.flatMap { NSRunningApplication(processIdentifier: $0.pid) }
    }

    private func minimizeCurrentWindow() {
        guard let pid = currentInfo?.pid else { return }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return }
        AXUIElementSetAttributeValue(
            value as! AXUIElement,
            kAXMinimizedAttribute as CFString,
            kCFBooleanTrue
        )
    }

    private func savePosition(_ origin: NSPoint, screen: NSScreen? = nil) {
        let target = screen
            ?? NSScreen.screens.first { $0.frame.contains(origin) }
            ?? panel.screen
        guard let target else { return }
        let defaults = UserDefaults.standard
        let key = displayKey(target)
        var xs = positionMap(Pref.positionXByDisplay)
        var ys = positionMap(Pref.positionYByDisplay)
        xs[key] = origin.x
        ys[key] = origin.y
        defaults.set(xs, forKey: Pref.positionXByDisplay)
        defaults.set(ys, forKey: Pref.positionYByDisplay)
    }

    private func displayKey(_ screen: NSScreen) -> String {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.stringValue ?? "\(screen.frame.origin.x),\(screen.frame.origin.y)"
    }

    private func positionMap(_ key: String) -> [String: Double] {
        let stored = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        return stored.compactMapValues { ($0 as? NSNumber)?.doubleValue }
    }

    private func savedPosition(for screen: NSScreen) -> NSPoint? {
        let key = displayKey(screen)
        let xs = positionMap(Pref.positionXByDisplay)
        let ys = positionMap(Pref.positionYByDisplay)
        if let x = xs[key], let y = ys[key] {
            return NSPoint(x: x, y: y)
        }
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Pref.positionSet) {
            let legacy = NSPoint(
                x: defaults.double(forKey: Pref.positionX),
                y: defaults.double(forKey: Pref.positionY)
            )
            if screen.frame.contains(legacy) {
                return legacy
            }
        }
        return nil
    }

    private func showMenu(at point: NSPoint, in target: NSView) {
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit MenuTitle", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        let previous = NSWorkspace.shared.frontmostApplication
        menu.popUp(positioning: nil, at: point, in: target)
        if let previous, previous.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previous.activate()
        }
    }

    @objc private func openSettings() {
        SettingsWindow.shared.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
