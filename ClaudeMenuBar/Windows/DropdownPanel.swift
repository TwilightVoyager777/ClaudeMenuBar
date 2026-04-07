import AppKit
import SwiftUI

final class DropdownPanel {
    private var panel: NSPanel?

    func show<Content: View>(view: Content, anchorOrigin: NSPoint, anchorWidth: CGFloat) {
        let width: CGFloat = 240
        let x = anchorOrigin.x
        let estimatedHeight: CGFloat = 120
        let y = anchorOrigin.y - estimatedHeight
        let frame = NSRect(x: x, y: y, width: width, height: estimatedHeight)

        if panel == nil {
            panel = makePanel()
        }
        let hostingView = NSHostingView(rootView: view)
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
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return p
    }
}
