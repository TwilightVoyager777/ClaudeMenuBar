import AppKit
import SwiftUI

final class DropdownPanel {
    private var panel: NSPanel?

    func show<Content: View>(view: Content, below buttonFrame: NSRect) {
        let width: CGFloat = 240
        let estimatedHeight: CGFloat = 120
        let x = buttonFrame.midX - width / 2
        let y = buttonFrame.minY - estimatedHeight
        let frame = NSRect(x: x, y: y, width: width, height: estimatedHeight)

        if panel == nil {
            panel = makePanel()
        }
        panel!.contentView = NSHostingView(rootView: view)
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
