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
    private let panel: BarPanel
    private let container = NSView()
    private let view = BarView()
    private var glassHost: NSView?
    private let queue = DispatchQueue(label: "com.zeb.windowtitles.query")
    private var timer: Timer?
    private var menuTimer: Timer?
    private var menuOpen = false
    private var busy = false
    private var pending = false

    override init() {
        panel = BarPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none

        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
        panel.contentView = container

        view.onLeftClick = { SettingsWindow.shared.show() }
        view.onRightClick = { [weak self] point in self?.showMenu(at: point) }
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

        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer

        let menuTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMenuState()
        }
        RunLoop.main.add(menuTimer, forMode: .common)
        self.menuTimer = menuTimer
    }

    private func updateMenuState() {
        let frontPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let open = MenuBarGeometry.hasOpenMenu(pid: frontPid)
        guard open != menuOpen else { return }
        menuOpen = open
        if open {
            hide()
        } else {
            refresh()
        }
    }

    @objc func refresh() {
        guard AXIsProcessTrusted() else {
            hide()
            return
        }

        let frontmost = NSWorkspace.shared.frontmostApplication
        guard let frontPid = frontmost?.processIdentifier,
              frontPid != ProcessInfo.processInfo.processIdentifier else {
            hide()
            return
        }

        if busy {
            pending = true
            return
        }
        busy = true

        queue.async { [weak self] in
            let info = Yabai.queryFrontWindow()
            let menuBar = MenuBarGeometry.menuBar(pid: frontPid)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                self.apply(info: info, menuBar: menuBar)
                if self.pending {
                    self.pending = false
                    self.refresh()
                }
            }
        }
    }

    private func apply(info: FrontWindowInfo?, menuBar: MenuBarGeometry.MenuBar?) {
        guard let info,
              !info.title.isEmpty,
              !info.fullscreen,
              !menuOpen,
              let menuBar,
              let screen = MenuBarGeometry.screen(forAXPoint: menuBar.anchor) else {
            hide()
            return
        }

        let defaults = UserDefaults.standard
        let barHeight = MenuBarGeometry.height(for: screen)
        let fontSize = CGFloat(defaults.double(forKey: Pref.fontSize))
        let fontFamily = defaults.string(forKey: Pref.fontFamily) ?? ""
        let iconStyle = IconStyle(rawValue: defaults.string(forKey: Pref.iconStyle) ?? "") ?? .appFont
        let padding = CGFloat(defaults.double(forKey: Pref.padding))
        let letterSpacing = CGFloat(defaults.double(forKey: Pref.letterSpacing))
        let wordSpacing = CGFloat(defaults.double(forKey: Pref.wordSpacing))
        let gap = CGFloat(defaults.double(forKey: Pref.gap))
        let inset = CGFloat(defaults.double(forKey: Pref.leftInset))
        let maxWidth = CGFloat(defaults.double(forKey: Pref.maxWidth))
        let truncation = TruncationStyle(rawValue: defaults.string(forKey: Pref.truncationStyle) ?? "") ?? .end
        let background = BarBackgroundStyle(rawValue: defaults.string(forKey: Pref.backgroundStyle) ?? "") ?? .liquidGlass
        let scrolling = defaults.bool(forKey: Pref.scrollTitles)

        let cleanedTitle = TitleCleaner.clean(info.title, stripBrowserNames: defaults.bool(forKey: Pref.stripBrowserNames))
        let title = scrolling
            ? cleanedTitle
            : TitleCleaner.truncate(cleanedTitle, maxLength: defaults.integer(forKey: Pref.maxLength), style: truncation)

        let x = max(menuBar.endX + gap + inset, screen.frame.minX + 2)
        var cap = maxWidth
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
        guard cap >= 40 else {
            hide()
            return
        }

        let nativeIcon = iconStyle == .native
            ? NSRunningApplication(processIdentifier: info.pid)?.icon
            : nil

        func makeContent(_ size: CGFloat) -> BarContent {
            let font = FontResolver.font(family: fontFamily, size: size)
            var glyph: NSAttributedString?
            if iconStyle == .appFont, let character = AppIconFont.shared.glyph(for: info.app) {
                let iconFont = NSFont(name: AppIconFont.fontName, size: size + 3) ?? font
                glyph = NSAttributedString(
                    string: character,
                    attributes: [.font: iconFont, .foregroundColor: NSColor.labelColor]
                )
            }
            return BarContent(
                title: title,
                font: font,
                color: .labelColor,
                icon: nativeIcon,
                glyph: glyph,
                padding: padding,
                spacing: 5,
                letterSpacing: letterSpacing,
                wordSpacing: wordSpacing,
                truncation: truncation,
                scrolling: scrolling,
                background: background
            )
        }

        var size = fontSize
        var content = makeContent(size)
        view.content = content
        var natural = view.naturalWidth(forHeight: barHeight)

        if defaults.bool(forKey: Pref.autoScale) {
            let minimum = max(8, fontSize * 0.6)
            while natural > cap && size > minimum + 0.001 {
                size = max(minimum, size - 0.5)
                content = makeContent(size)
                view.content = content
                natural = view.naturalWidth(forHeight: barHeight)
            }
        }

        updateGlass(background == .liquidGlass)
        let width = min(natural, cap)

        let frame = NSRect(
            x: x,
            y: screen.frame.maxY - barHeight,
            width: width,
            height: barHeight
        )
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        view.needsDisplay = true
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func updateGlass(_ enabled: Bool) {
        if enabled {
            if glassHost == nil {
                if #available(macOS 26.0, *) {
                    let glass = NSGlassEffectView()
                    glass.style = .regular
                    glass.cornerRadius = 6
                    glass.frame = container.bounds
                    glass.autoresizingMask = [.width, .height]
                    container.addSubview(glass)
                    glassHost = glass
                } else {
                    let blur = NSVisualEffectView()
                    blur.material = .underWindowBackground
                    blur.blendingMode = .behindWindow
                    blur.state = .active
                    blur.wantsLayer = true
                    blur.layer?.cornerRadius = 6
                    blur.layer?.masksToBounds = true
                    blur.frame = container.bounds
                    blur.autoresizingMask = [.width, .height]
                    container.addSubview(blur)
                    glassHost = blur
                }
            }
            guard let glassHost else { return }
            if view.superview !== glassHost {
                view.frame = glassHost.bounds
                view.autoresizingMask = [.width, .height]
                if #available(macOS 26.0, *), let glass = glassHost as? NSGlassEffectView {
                    glass.contentView = view
                } else {
                    glassHost.addSubview(view)
                }
            }
            glassHost.isHidden = false
        } else {
            if view.superview !== container {
                view.frame = container.bounds
                view.autoresizingMask = [.width, .height]
                container.addSubview(view)
            }
            glassHost?.isHidden = true
        }
    }

    private func hide() {
        if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private func showMenu(at point: NSPoint) {
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
        menu.popUp(positioning: nil, at: point, in: view)
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
