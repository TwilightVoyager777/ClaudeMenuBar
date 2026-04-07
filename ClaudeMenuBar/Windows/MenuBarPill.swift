import AppKit
import SwiftUI

final class MenuBarPill {
    private var panel: NSPanel?

    func show<Content: View>(view: Content, on screen: NSScreen, pillWidth: CGFloat) {
        let origin = PillPositioner.pillOrigin(on: screen, pillWidth: pillWidth)
        let size = NSSize(width: pillWidth, height: PillPositioner.pillHeight)
        let frame = NSRect(origin: origin, size: size)

        if panel == nil {
            panel = makePanel()
        }
        let hostingView = NSHostingView(rootView: view.fixedSize())
        panel!.contentView = hostingView
        panel!.setFrame(frame, display: true)
        panel!.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .init(Int(CGWindowLevelForKey(.statusWindow)) + 1)
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.ignoresMouseEvents = true
        return p
    }
}
