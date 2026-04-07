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

    /// Draws a keyboard keycap as a template image.
    /// Uses fill + clear-blend cutout to create a solid rim with 3-D depth strip at the bottom.
    private static func makeKeycapIcon(size: CGFloat = 17) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // Key proportions: wide and short, like a real key
            let kw: CGFloat = 15.5
            let kh: CGFloat = 10.5
            let kx: CGFloat = (size - kw) / 2   // 0.75
            let ky: CGFloat = (size - kh) / 2   // 3.25

            // 1. Fill the full key body
            ctx.setFillColor(NSColor.black.cgColor)
            let body = NSBezierPath(
                roundedRect: NSRect(x: kx, y: ky, width: kw, height: kh),
                xRadius: 3.0, yRadius: 3.0
            )
            body.fill()

            // 2. Carve out the recessed top face with .clear blend
            //    Side & top inset: 2 pt (thin rim)
            //    Bottom inset: 3.5 pt (thick = visible depth/side face)
            let si: CGFloat = 2.0    // side + top inset
            let di: CGFloat = 3.5   // bottom depth inset
            ctx.setBlendMode(.clear)
            let face = NSBezierPath(
                roundedRect: NSRect(x: kx + si, y: ky + di,
                                    width: kw - si * 2, height: kh - si - di),
                xRadius: 1.5, yRadius: 1.5
            )
            face.fill()
            ctx.setBlendMode(.normal)

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
