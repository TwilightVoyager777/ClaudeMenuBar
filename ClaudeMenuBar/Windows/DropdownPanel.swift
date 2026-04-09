import AppKit
import SwiftUI

final class DropdownPanel {
    private var window: ClickThroughWindow?

    func show<Content: View>(view: Content, below buttonFrame: NSRect) {
        if window == nil {
            window = makeWindow()
        }

        let hosting = FirstMouseHostingView(rootView: view)
        window!.contentView = hosting

        // Use the actual SwiftUI content size instead of a hardcoded estimate
        let contentSize = hosting.fittingSize
        let gap: CGFloat = 4
        let x = buttonFrame.midX - contentSize.width / 2
        let y = buttonFrame.minY - gap - contentSize.height
        let frame = NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)

        window!.setFrame(frame, display: true)
        window!.orderFrontRegardless()

        // Activate the app so the window can become key
        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window!.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> ClickThroughWindow {
        let w = ClickThroughWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.isMovableByWindowBackground = false
        w.level = .init(Int(CGWindowLevelForKey(.statusWindow)) + 1)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return w
    }
}

/// Window that accepts first mouse click and can become key.
final class ClickThroughWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Make ourselves key on first click, then forward the event
        if !isKeyWindow {
            makeKey()
        }
        super.mouseDown(with: event)
    }
}

/// NSHostingView that accepts clicks even when the window isn't key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
