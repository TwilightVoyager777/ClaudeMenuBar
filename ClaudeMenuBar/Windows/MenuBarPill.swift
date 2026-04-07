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
        button.image = Self.makeTerminalIcon()
    }

    /// Draws a ">_" terminal prompt as a template image.
    private static func makeTerminalIcon(size: CGFloat = 17) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSColor.black.setStroke()
            let lw: CGFloat = 1.7

            // ">" chevron
            let chevron = NSBezierPath()
            chevron.move(to:  NSPoint(x: 4.5, y: 12.5))
            chevron.line(to:  NSPoint(x: 9.5,  y: 8.5))
            chevron.line(to:  NSPoint(x: 4.5, y: 4.5))
            chevron.lineWidth      = lw
            chevron.lineCapStyle   = .round
            chevron.lineJoinStyle  = .round
            chevron.stroke()

            // "_" cursor (sits at baseline, right of chevron)
            let cursor = NSBezierPath()
            cursor.move(to:  NSPoint(x: 11.0, y: 5.5))
            cursor.line(to:  NSPoint(x: 15.5, y: 5.5))
            cursor.lineWidth     = lw
            cursor.lineCapStyle  = .round
            cursor.stroke()

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
