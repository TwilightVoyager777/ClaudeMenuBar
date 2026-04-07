import AppKit
import SwiftUI

final class MenuBarPill {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    /// Screen frame of the button, used to anchor the dropdown panel below it
    var buttonScreenFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    init() {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        showIcon()
    }

    /// Revert to the small idle icon
    func showIcon() {
        statusItem.length = NSStatusItem.squareLength
        guard let button = statusItem.button else { return }
        button.subviews.forEach { $0.removeFromSuperview() }
        button.image = Self.makeKeycapIcon()
    }

    /// Draws a keyboard keycap as a template image
    private static func makeKeycapIcon(size: CGFloat = 17) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSColor.black.setStroke()
            let lw: CGFloat = 1.5

            // Outer key body — slightly rounded rect
            let outer = NSBezierPath(
                roundedRect: NSRect(x: 1.0, y: 1.0, width: 15.0, height: 14.0),
                xRadius: 3.0, yRadius: 3.0
            )
            outer.lineWidth = lw
            outer.stroke()

            // Inner top face — inset with 3 pt bottom gap and 2 pt top gap
            // creating a subtle 3D "viewed from above" perspective
            let inner = NSBezierPath(
                roundedRect: NSRect(x: 3.5, y: 4.0, width: 10.0, height: 9.0),
                xRadius: 1.8, yRadius: 1.8
            )
            inner.lineWidth = lw * 0.75
            inner.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    /// Show a SwiftUI view inline in the menu bar at the given width
    func show<Content: View>(view: Content, pillWidth: CGFloat) {
        let barHeight = NSStatusBar.system.thickness
        statusItem.length = pillWidth

        guard let button = statusItem.button else { return }
        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }

        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(x: 0, y: 0, width: pillWidth, height: barHeight)
        button.addSubview(hosting)
    }

    func hide() {
        showIcon()
    }
}
