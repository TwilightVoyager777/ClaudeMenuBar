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
        button.image = Self.makeSparkleIcon()
    }

    /// Draws a ✦ four-pointed sparkle icon as a template image
    private static func makeSparkleIcon(size: CGFloat = 17) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let cx = size / 2
            let cy = size / 2
            let tipR  = size * 0.46   // how far the pointed tips extend
            let waist = size * 0.085  // half-width at center crossing

            // Vertical elongated diamond
            let v = NSBezierPath()
            v.move(to:   NSPoint(x: cx,          y: cy + tipR))
            v.line(to:   NSPoint(x: cx + waist,  y: cy))
            v.line(to:   NSPoint(x: cx,          y: cy - tipR))
            v.line(to:   NSPoint(x: cx - waist,  y: cy))
            v.close()

            // Horizontal elongated diamond
            let h = NSBezierPath()
            h.move(to:   NSPoint(x: cx + tipR,   y: cy))
            h.line(to:   NSPoint(x: cx,          y: cy + waist))
            h.line(to:   NSPoint(x: cx - tipR,   y: cy))
            h.line(to:   NSPoint(x: cx,          y: cy - waist))
            h.close()

            NSColor.black.setFill()
            v.fill()
            h.fill()
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
