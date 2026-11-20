import CoreGraphics

// Pure rules for the panel while the front app's menus change. Kept free of
// AppKit so the decisions can be tested without a running window server.
enum ClampPolicy {
    enum Decision: Equatable {
        case keep
        case move(CGRect)
        case hide
    }

    static let minimumWidth: CGFloat = 24
    static let screenMargin: CGFloat = 2

    static func decision(
        current: CGRect,
        endX: CGFloat,
        gap: CGFloat,
        inset: CGFloat,
        screen: CGRect
    ) -> Decision {
        let x = max(endX + gap + inset, screen.minX + screenMargin)
        guard current.minX < x else { return .keep }
        let available = screen.maxX - x - screenMargin
        // A short title still fits; hide only when no room is left.
        guard available >= minimumWidth else { return .hide }
        var frame = current
        frame.origin.x = x
        frame.size.width = min(current.width, available)
        return .move(frame)
    }
}

// Counts identical menu end measurements. The count survives a hidden panel,
// so tracking resumes where it stopped.
struct StableEndXTracker {
    static let requiredTicks = 15

    private(set) var stableTicks = 0
    private var lastEndX: CGFloat?

    // Reports true once 15 readings match the previous one.
    mutating func record(_ endX: CGFloat?) -> Bool {
        guard let endX else {
            reset()
            return false
        }
        guard endX == lastEndX else {
            stableTicks = 0
            lastEndX = endX
            return false
        }
        stableTicks += 1
        return stableTicks >= Self.requiredTicks
    }

    mutating func resetTicks() {
        stableTicks = 0
    }

    mutating func reset() {
        resetTicks()
        lastEndX = nil
    }
}
