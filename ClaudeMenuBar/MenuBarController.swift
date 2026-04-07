import AppKit
import SwiftUI
import Combine

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

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Test: Working",   action: #selector(testWorking),      keyEquivalent: "1").target = self
        menu.addItem(withTitle: "Test: WaitInput", action: #selector(testWaitingInput), keyEquivalent: "2").target = self
        menu.addItem(withTitle: "Test: Complete",  action: #selector(testComplete),     keyEquivalent: "3").target = self
        menu.addItem(withTitle: "Test: Silent",    action: #selector(testSilent),       keyEquivalent: "0").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ClaudeMenuBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        pill.statusItem.menu = menu
    }

    @objc private func testWorking()      { stateManager.transition(to: .working(tool: "Bash", detail: "ls -la")) }
    @objc private func testWaitingInput() { stateManager.transition(to: .waitingInput(message: "Allow this action?", options: InputOption.defaults)) }
    @objc private func testComplete()     { stateManager.transition(to: .complete) }
    @objc private func testSilent()       { stateManager.transition(to: .silent) }

    private func setupHTTPServer() {
        httpServer.onEventData = { [weak self] data in
            guard let self else { return }
            let raw = String(data: data, encoding: .utf8) ?? "<invalid utf8>"
            NSLog("[CMB] received data: %@", raw)
            guard let event = try? JSONDecoder().decode(ClaudeEvent.self, from: data) else {
                NSLog("[CMB] JSON decode failed")
                return
            }
            NSLog("[CMB] decoded event: %@", event.event)
            Task { @MainActor in
                if let newState = self.eventRouter.route(event) {
                    NSLog("[CMB] routing to state: %@", String(describing: newState))
                    self.stateManager.transition(to: newState)
                } else {
                    NSLog("[CMB] eventRouter returned nil for event: %@", event.event)
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
        NSLog("[CMB] render called with state: %@", String(describing: state))

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
            if let buttonFrame = pill.buttonScreenFrame {
                let dropView = DropdownView(message: message, options: options) { [weak self] option in
                    KeystrokeReplay.type(option.id)
                    self?.stateManager.transition(to: .silent)
                }
                dropdown.show(view: dropView, below: buttonFrame)
            }
            NSSound.beep()

        case .complete:
            hotkeys.disable()
            dropdown.hide()
            pill.show(view: CompleteView(), pillWidth: 120)
        }
    }
}
