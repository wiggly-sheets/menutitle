import AppKit
import ApplicationServices

enum MenuBarGeometry {
    struct MenuBar {
        let endX: CGFloat
        /// A point on the menu bar in AX (top-left origin) coordinates.
        let anchor: CGPoint
    }

    static func height(for screen: NSScreen) -> CGFloat {
        let height = screen.frame.maxY - screen.visibleFrame.maxY
        if height >= 20 { return height }
        return max(NSStatusBar.system.thickness, 24)
    }

    /// Left edge of the camera housing on screens that have a notch.
    static func notchLeftX(for screen: NSScreen) -> CGFloat? {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              left.maxX < right.minX else { return nil }
        return left.maxX
    }

    /// Right edge of the front app's menu bar items and a point on that menu bar.
    static func menuBar(pid: pid_t?) -> MenuBar? {
        guard let pid else { return nil }

        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.25)

        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBarRef, CFGetTypeID(menuBarRef) == AXUIElementGetTypeID() else { return nil }
        let menuBar = menuBarRef as! AXUIElement

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let items = childrenRef as? [AXUIElement], !items.isEmpty else { return nil }

        var endX: CGFloat = 0
        var anchor: CGPoint?
        for item in items {
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &positionRef) == .success,
                  AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeRef) == .success,
                  let positionRef, let sizeRef,
                  CFGetTypeID(positionRef) == AXValueGetTypeID(),
                  CFGetTypeID(sizeRef) == AXValueGetTypeID() else { continue }

            var position = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
                  AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { continue }

            endX = max(endX, position.x + size.width)
            if anchor == nil, size.width > 0, size.height > 0 {
                anchor = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
            }
        }

        guard endX > 1, let anchor else { return nil }
        return MenuBar(endX: endX, anchor: anchor)
    }

    /// Screen containing an AX-space point. AX y grows downward from the top.
    static func screen(forAXPoint point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return nil }
        let appKitPoint = CGPoint(x: point.x, y: primary.frame.maxY - point.y)
        return screens.first { $0.frame.contains(appKitPoint) } ?? NSScreen.main ?? primary
    }

    /// True when the given app has a popup or menu window on screen.
    static func hasOpenMenu(pid: pid_t?) -> Bool {
        guard let pid,
              let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else { return false }

        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer >= menuLevel,
                  let owner = window[kCGWindowOwnerPID as String] as? Int, owner == Int(pid),
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue,
                  width > 40, height > 20 else { continue }
            return true
        }
        return false
    }

    /// Left edge of the first other menu-bar-level window that overlaps the
    /// region right of `afterX`. Catches overlays such as custom menu bar
    /// widgets that the system status items do not cover.
    static func leftmostObstructionX(
        screen: NSScreen,
        barHeight: CGFloat,
        afterX: CGFloat,
        excludingPid: pid_t
    ) -> CGFloat? {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let menuBarTop = primaryHeight - screen.frame.maxY

        var leftmost: CGFloat?
        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer >= 24,
                  let owner = window[kCGWindowOwnerPID as String] as? Int, owner != Int(excludingPid),
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let x = (bounds["X"] as? NSNumber)?.doubleValue,
                  let y = (bounds["Y"] as? NSNumber)?.doubleValue,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue else { continue }

            guard width > 20, width < Double(screen.frame.width) * 0.9,
                  height <= Double(barHeight) + 8,
                  abs(y - Double(menuBarTop)) <= 2,
                  x + width > Double(afterX) + 20 else { continue }

            let limit = CGFloat(x)
            leftmost = min(leftmost ?? limit, limit)
        }
        return leftmost
    }
}
