import AppKit
import SwiftUI

final class DropdownPanel {
    private var panel: KeyablePanel?

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
        NSApp.activate(ignoringOtherApps: true)
        panel!.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> KeyablePanel {
        let p = KeyablePanel(
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

/// NSPanel that can become key even with .nonactivatingPanel style.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
