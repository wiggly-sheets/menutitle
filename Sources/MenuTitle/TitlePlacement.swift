import CoreGraphics

// Pure rules for where the title panel goes on a display. Kept free of AppKit
// so each position can be tested without a running window server.
enum TitlePlacement {
    enum Anchor: Equatable {
        case left(CGFloat)
        case right(CGFloat)
        case center(CGFloat)
    }

    struct Result: Equatable {
        let anchor: Anchor
        let maximumWidth: CGFloat

        func x(for width: CGFloat) -> CGFloat {
            switch anchor {
            case .left(let x): return x
            case .right(let edge): return edge - width
            case .center(let center): return center - width / 2
            }
        }
    }

    static func place(
        position: PanelPosition,
        screen: CGRect,
        menuEndX: CGFloat,
        notch: (left: CGFloat, right: CGFloat)?,
        gap: CGFloat,
        inset: CGFloat,
        maximumWidth: CGFloat,
        obstructionX: CGFloat?
    ) -> Result? {
        switch position {
        case .custom:
            let cap = min(maximumWidth, screen.width - 4)
            guard cap >= ClampPolicy.minimumWidth else { return nil }
            return Result(
                anchor: .left(max(menuEndX + gap + inset, screen.minX + ClampPolicy.screenMargin)),
                maximumWidth: cap
            )
        case .menus:
            return besideMenus(
                screen: screen,
                menuEndX: menuEndX,
                notchLeft: notch?.left,
                gap: gap,
                inset: inset,
                maximumWidth: maximumWidth,
                obstructionX: obstructionX
            )
        case .notchLeft:
            guard let notch else {
                return besideMenus(
                    screen: screen,
                    menuEndX: menuEndX,
                    notchLeft: nil,
                    gap: gap,
                    inset: inset,
                    maximumWidth: maximumWidth,
                    obstructionX: obstructionX
                )
            }
            let left = max(menuEndX + gap, screen.minX + ClampPolicy.screenMargin)
            let edge = notch.left - gap
            let cap = min(maximumWidth, edge - left)
            return cap >= ClampPolicy.minimumWidth ? Result(anchor: .right(edge), maximumWidth: cap) : nil
        case .notchRight:
            guard let notch else {
                return besideMenus(
                    screen: screen,
                    menuEndX: menuEndX,
                    notchLeft: nil,
                    gap: gap,
                    inset: inset,
                    maximumWidth: maximumWidth,
                    obstructionX: obstructionX
                )
            }
            let x = notch.right + gap
            var cap = min(maximumWidth, screen.maxX - x - ClampPolicy.screenMargin)
            if let obstructionX {
                cap = min(cap, obstructionX - x - gap)
            }
            return cap >= ClampPolicy.minimumWidth ? Result(anchor: .left(x), maximumWidth: cap) : nil
        case .center:
            // A centered title would sit behind the notch. Use the menus then.
            guard notch == nil else {
                return besideMenus(
                    screen: screen,
                    menuEndX: menuEndX,
                    notchLeft: notch?.left,
                    gap: gap,
                    inset: inset,
                    maximumWidth: maximumWidth,
                    obstructionX: obstructionX
                )
            }
            let mid = screen.midX
            var cap = min(maximumWidth, screen.width - 2 * ClampPolicy.screenMargin)
            cap = min(cap, 2 * (mid - menuEndX - gap))
            if let obstructionX {
                cap = min(cap, 2 * (obstructionX - gap - mid))
            }
            return cap >= ClampPolicy.minimumWidth ? Result(anchor: .center(mid), maximumWidth: cap) : nil
        }
    }

    private static func besideMenus(
        screen: CGRect,
        menuEndX: CGFloat,
        notchLeft: CGFloat?,
        gap: CGFloat,
        inset: CGFloat,
        maximumWidth: CGFloat,
        obstructionX: CGFloat?
    ) -> Result? {
        let x = max(menuEndX + gap + inset, screen.minX + ClampPolicy.screenMargin)
        var cap = min(maximumWidth, screen.maxX - x - ClampPolicy.screenMargin)
        if let notchLeft, x < notchLeft {
            cap = min(cap, notchLeft - x - gap)
        }
        if let obstructionX {
            cap = min(cap, obstructionX - x - gap)
        }
        return cap >= ClampPolicy.minimumWidth ? Result(anchor: .left(x), maximumWidth: cap) : nil
    }
}
