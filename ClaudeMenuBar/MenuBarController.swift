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
    /// The app that was frontmost before the dropdown stole focus.
    private var previousApp: NSRunningApplication?

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
                                   action: #selector(toggleLaunchAtLogin(_:)),
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
            print("[HTTP] received \(data.count) bytes")
            let event: ClaudeEvent
            do {
                event = try JSONDecoder().decode(ClaudeEvent.self, from: data)
            } catch {
                print("[HTTP] DECODE FAILED: \(error)")
                print("[HTTP] raw: \(String(data: data.prefix(300), encoding: .utf8) ?? "?")")
                return
            }
            print("[HTTP] event: \(event.event) tool: \(event.tool ?? "-")")
            Task { @MainActor in
                if let newState = self.eventRouter.route(event) {
                    print("[State] → \(newState)")
                    self.stateManager.transition(to: newState)
                } else {
                    print("[State] route returned nil")
                }
            }
        }
        do {
            try httpServer.start()
        } catch {
            let alert = NSAlert()
            alert.messageText = "ClaudeMenuBar — Port Unavailable"
            alert.informativeText = "Port 36787 is already in use."
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
                guard case .waitingInput(_, let options) = self.stateManager.state else { return }
                if key == "esc" {
                    self.stateManager.transition(to: .silent)
                } else if options.contains(where: { $0.id == key }) {
                    self.respondWith(key)
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
            restorePreviousApp()

        case .working(let tool, let detail):
            hotkeys.disable()
            dropdown.hide()
            restorePreviousApp()
            let width = min(max(CGFloat(tool.count) * 8 + 60, 80), 180)
            pill.show(view: WorkingView(tool: tool, detail: detail), pillWidth: width)

        case .waitingInput(let message, let options):
            // Capture the frontmost app BEFORE the dropdown steals focus
            previousApp = NSWorkspace.shared.frontmostApplication
            hotkeys.enable()
            pill.show(view: WaitingAnchorView(), pillWidth: 160)
            let dropView = DropdownView(message: message, options: options) { [weak self] option in
                self?.respondWith(option.id)
            }
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
            restorePreviousApp()
            pill.show(view: CompleteView(), pillWidth: 120)
        }
    }

    private func respondWith(_ optionId: String) {
        guard case .waitingInput(_, let options) = stateManager.state,
              let index = options.firstIndex(where: { $0.id == optionId }) else { return }
        let terminalKey = "\(index + 1)"
        previousApp = nil   // Clear so render(.silent) won't double-activate
        stateManager.transition(to: .silent)
        // Always activate a terminal — previousApp might be a browser or other non-terminal app.
        activateTerminal()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            KeystrokeReplay.type(terminalKey)
        }
    }

    // MARK: - App activation

    private static let terminalBundleIDs = [
        "com.mitchellh.ghostty",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
    ]

    private func activateApp(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }

    /// Restore the user to whatever app they were in before the dropdown appeared.
    private func restorePreviousApp() {
        guard let app = previousApp else { return }
        previousApp = nil
        activateApp(app)
    }

    /// Find and activate a running terminal app.
    private func activateTerminal() {
        let running = NSWorkspace.shared.runningApplications
        for id in Self.terminalBundleIDs {
            if let app = running.first(where: { $0.bundleIdentifier == id }) {
                activateApp(app)
                return
            }
        }
    }
}
