import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let stateManager = StateManager()
    private let eventRouter = EventRouter()
    private let httpServer = HTTPServer()
    private let pill = MenuBarPill()
    private let dropdown = DropdownPanel()
    private let hotkeys = GlobalHotkeys()
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        setupStatusItem()
        setupHTTPServer()
        setupHotkeys()
        observeState()
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right",
                                   accessibilityDescription: "ClaudeMenuBar")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit ClaudeMenuBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func statusBarButtonClicked() {}

    private func setupHTTPServer() {
        httpServer.onEventData = { [weak self] data in
            guard let self else { return }
            guard let event = try? JSONDecoder().decode(ClaudeEvent.self, from: data) else { return }
            Task { @MainActor in
                if let newState = self.eventRouter.route(event) {
                    self.stateManager.transition(to: newState)
                }
            }
        }
        try? httpServer.start()
    }

    private func setupHotkeys() {
        hotkeys.onKey = { [weak self] key in
            guard let self else { return }
            Task { @MainActor in
                guard case .waitingInput = self.stateManager.state else { return }
                if key == "esc" {
                    self.stateManager.transition(to: .silent)
                } else {
                    KeystrokeReplay.type(key)
                    self.stateManager.transition(to: .silent)
                }
            }
        }
    }

    private func observeState() {
        cancellable = stateManager.$state.sink { [weak self] state in
            Task { @MainActor in
                self?.render(state: state)
            }
        }
    }

    private func render(state: AppState) {
        guard let screen = NSScreen.main else { return }

        switch state {
        case .silent:
            hotkeys.disable()
            pill.hide()
            dropdown.hide()

        case .working(let tool, let detail):
            hotkeys.disable()
            dropdown.hide()
            let view = WorkingView(tool: tool, detail: detail)
            let width: CGFloat = CGFloat(tool.count + detail.count) * 6 + 60
            pill.show(view: view, on: screen, pillWidth: min(max(width, 120), 300))

        case .waitingInput(let message, let options):
            hotkeys.enable()
            let anchorView = WaitingAnchorView()
            let origin = PillPositioner.pillOrigin(on: screen, pillWidth: 160)
            pill.show(view: anchorView, on: screen, pillWidth: 160)
            let dropView = DropdownView(message: message, options: options) { [weak self] option in
                KeystrokeReplay.type(option.id)
                self?.stateManager.transition(to: .silent)
            }
            dropdown.show(view: dropView, anchorOrigin: origin, anchorWidth: 160)
            NSSound.beep()

        case .complete:
            hotkeys.disable()
            dropdown.hide()
            let view = CompleteView()
            pill.show(view: view, on: screen, pillWidth: 120)
        }
    }
}
