import AppKit
import ApplicationServices

/// Watches the front app's focused window and title so the bar updates as soon
/// as the window changes, instead of waiting for the polling timer.
final class FrontWindowObserver {
    private var observer: AXObserver?
    private var pid: pid_t = 0
    private var appElement: AXUIElement?
    private var titleElement: AXUIElement?
    private var onEvent: (() -> Void)?

    func start(onEvent: @escaping () -> Void) {
        self.onEvent = onEvent
    }

    func observe(pid: pid_t) {
        guard AXIsProcessTrusted(), pid != self.pid else { return }
        stop()
        self.pid = pid

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let watcher = Unmanaged<FrontWindowObserver>.fromOpaque(refcon).takeUnretainedValue()
            watcher.handle(notification as String, element: element)
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        self.observer = observer

        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        appElement = app
        AXObserverAddNotification(observer, app, kAXFocusedWindowChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(observer, app, kAXWindowCreatedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)

        attachTitleNotification()
    }

    func stop() {
        if let observer {
            if let appElement {
                AXObserverRemoveNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString)
                AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
            }
            if let titleElement {
                AXObserverRemoveNotification(observer, titleElement, kAXTitleChangedNotification as CFString)
                AXObserverRemoveNotification(observer, titleElement, kAXUIElementDestroyedNotification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        appElement = nil
        titleElement = nil
        pid = 0
    }

    private func handle(_ notification: String, element: AXUIElement) {
        if notification == kAXUIElementDestroyedNotification as String {
            titleElement = nil
            onEvent?()
            return
        }
        if notification == kAXFocusedWindowChangedNotification as String {
            attachTitleNotification()
        }
        onEvent?()
    }

    private func attachTitleNotification() {
        guard let observer, let appElement else { return }
        if let titleElement {
            AXObserverRemoveNotification(observer, titleElement, kAXTitleChangedNotification as CFString)
        }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            titleElement = nil
            return
        }
        let window = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(window, 0.25)
        titleElement = window
        AXObserverAddNotification(observer, window, kAXTitleChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        // Closing the last window sends no focus or app-activation change.
        AXObserverAddNotification(observer, window, kAXUIElementDestroyedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
    }
}
