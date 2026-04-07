import AppKit

enum PillPositioner {
    /// Approximate notch width in points for MacBook Pro (14" and 16")
    static let notchWidth: CGFloat = 210
    static let pillHeight: CGFloat = 22

    /// X coordinate where the pill's left edge should start (right of notch)
    static func notchRightEdge(
        screenWidth: CGFloat,
        notchWidth: CGFloat = PillPositioner.notchWidth,
        gap: CGFloat = 8
    ) -> CGFloat {
        screenWidth / 2 + notchWidth / 2 + gap
    }

    /// Full origin point for the pill NSPanel on a given screen
    static func pillOrigin(on screen: NSScreen, pillWidth: CGFloat) -> NSPoint {
        let screenFrame = screen.frame
        let menuBarHeight = NSStatusBar.system.thickness
        let hasNotch = screen.safeAreaInsets.top > 0
        let effectiveNotchWidth = hasNotch ? Self.notchWidth : 0

        let x = notchRightEdge(
            screenWidth: screenFrame.width,
            notchWidth: effectiveNotchWidth
        )
        let y = screenFrame.maxY - menuBarHeight + (menuBarHeight - pillHeight) / 2
        return NSPoint(x: screenFrame.minX + x, y: y)
    }
}
