import AppKit
import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private let stateManager = StateManager()
    private let eventRouter = EventRouter()
    private let httpServer = HTTPServer()
    private let pill = MenuBarPill()
    private let dropdown = DropdownPanel()
    private let hotkeys = GlobalHotkeys()
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        setupMenu()
        setupHTTPServer()
        setupHotkeys()
        observeState()
    }

    // MARK: - Menu

    private func setupMenu() {
        let loginItem = NSMenuItem(title: "Launch at Login",
                                   action: #selector(toggleLaunchAtLogin),
                                   keyEquivalent: "")
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        let menu = NSMenu()
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ClaudeMenuBar",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        pill.statusItem.menu = menu
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change login item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - HTTP Server

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
        do {
            try httpServer.start()
        } catch {
            let alert = NSAlert()
            alert.messageText = "ClaudeMenuBar — Port Unavailable"
            alert.informativeText = "Port 36787 is already in use. Another instance may be running.\n\nClaude Code events won't be received."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Hotkeys

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

    // MARK: - State observation

    private func observeState() {
        cancellable = stateManager.$state.sink { [weak self] state in
            Task { @MainActor in
                self?.render(state: state)
            }
        }
    }

    private func render(state: AppState) {
        switch state {
        case .silent:
            hotkeys.disable()
            pill.hide()
            dropdown.hide()

        case .working(let tool, let detail):
            hotkeys.disable()
            dropdown.hide()
            let width = min(max(CGFloat(tool.count + detail.count) * 6 + 60, 120), 300)
            pill.show(view: WorkingView(tool: tool, detail: detail), pillWidth: width)

        case .waitingInput(let message, let options):
            hotkeys.enable()
            pill.show(view: WaitingAnchorView(), pillWidth: 160)
            let dropView = DropdownView(message: message, options: options) { [weak self] option in
                KeystrokeReplay.type(option.id)
                self?.stateManager.transition(to: .silent)
            }
            // Defer one run-loop so the status item layout updates before we read its frame.
            // Re-check state to avoid showing a stale dropdown if the state already changed.
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      case .waitingInput = self.stateManager.state,
                      let frame = self.pill.buttonScreenFrame else { return }
                self.dropdown.show(view: dropView, below: frame)
            }
            NSSound.beep()

        case .complete:
            hotkeys.disable()
            dropdown.hide()
            pill.show(view: CompleteView(), pillWidth: 120)
        }
    }
}
