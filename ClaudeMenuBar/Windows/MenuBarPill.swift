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
        button.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right",
                               accessibilityDescription: "ClaudeMenuBar")
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
