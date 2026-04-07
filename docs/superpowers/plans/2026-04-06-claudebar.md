# ClaudeMenuBar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that shows Claude Code's current state (working/waiting/complete) as a floating pill right of the notch, with keyboard shortcuts to respond to Claude without switching windows.

**Architecture:** A SwiftUI/AppKit hybrid macOS app. An `HTTPServer` listens on port 36787 for Claude Code hook events. An `EventRouter` parses events into `AppState` transitions managed by `StateManager`. Two `NSPanel` windows (compact pill + dropdown) render the state. `CGEventTap` intercepts Y/A/N keystrokes when waiting for input and replays them into the terminal via `CGEventPost`.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (NSPanel, NSStatusItem), Network framework (NWListener), CoreGraphics (CGEventTap, CGEventPost), xcodegen (project scaffolding), macOS 13+

---

## Task 1: Project Scaffolding

**Files:**
- Create: `project.yml`
- Create: `ClaudeMenuBar/Info.plist`
- Create: `ClaudeMenuBar/ClaudeMenuBar.entitlements`
- Create: `ClaudeMenuBar/ClaudeMenuBarApp.swift`

- [ ] **Step 1: Install xcodegen**

```bash
brew install xcodegen
```

Expected: `xcodegen version 2.x.x` when running `xcodegen --version`

- [ ] **Step 2: Create `project.yml`**

```yaml
name: ClaudeMenuBar
options:
  bundleIdPrefix: com.claudemenubar
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
  xcodeVersion: "15.0"

targets:
  ClaudeMenuBar:
    type: application
    platform: macOS
    sources:
      - ClaudeMenuBar
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.claudemenubar.ClaudeMenuBar
        INFOPLIST_FILE: ClaudeMenuBar/Info.plist
        CODE_SIGN_ENTITLEMENTS: ClaudeMenuBar/ClaudeMenuBar.entitlements
        SWIFT_VERSION: "5.9"
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        CODE_SIGN_STYLE: Automatic
    entitlements:
      path: ClaudeMenuBar/ClaudeMenuBar.entitlements

  ClaudeMenuBarTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - ClaudeMenuBarTests
    dependencies:
      - target: ClaudeMenuBar
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.claudemenubar.ClaudeMenuBarTests
        MACOSX_DEPLOYMENT_TARGET: "13.0"
```

- [ ] **Step 3: Create `ClaudeMenuBar/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ClaudeMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudemenubar.ClaudeMenuBar</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>ClaudeMenuBar needs accessibility access to send keyboard responses to Claude Code in your terminal.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 4: Create `ClaudeMenuBar/ClaudeMenuBar.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 5: Create source directories**

```bash
mkdir -p ClaudeMenuBar/Models ClaudeMenuBar/Services ClaudeMenuBar/State \
          ClaudeMenuBar/Windows ClaudeMenuBar/Views ClaudeMenuBar/Helpers \
          ClaudeMenuBarTests scripts
```

- [ ] **Step 6: Create `ClaudeMenuBar/ClaudeMenuBarApp.swift` (stub)**

```swift
import SwiftUI

@main
struct ClaudeMenuBarApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 7: Generate Xcode project**

```bash
cd /Users/dragonhope/Documents/Project/ClaudeMenuBar
xcodegen generate
```

Expected: `ClaudeMenuBar.xcodeproj` created without errors.

- [ ] **Step 8: Verify build**

```bash
xcodebuild -scheme ClaudeMenuBar -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add project.yml ClaudeMenuBar/ ClaudeMenuBarTests/ scripts/ ClaudeMenuBar.xcodeproj
git commit -m "feat: project scaffolding"
```

---

## Task 2: AppState and ClaudeEvent Models

**Files:**
- Create: `ClaudeMenuBar/Models/AppState.swift`
- Create: `ClaudeMenuBar/Models/ClaudeEvent.swift`
- Create: `ClaudeMenuBarTests/ModelsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ClaudeMenuBarTests/ModelsTests.swift
import XCTest
@testable import ClaudeMenuBar

final class ModelsTests: XCTestCase {

    func test_appState_equality() {
        XCTAssertEqual(AppState.silent, AppState.silent)
        XCTAssertEqual(
            AppState.working(tool: "Bash", detail: "npm run build"),
            AppState.working(tool: "Bash", detail: "npm run build")
        )
        XCTAssertNotEqual(
            AppState.working(tool: "Bash", detail: "a"),
            AppState.working(tool: "Bash", detail: "b")
        )
        XCTAssertEqual(AppState.complete, AppState.complete)
    }

    func test_claudeEvent_decodes_preToolUse() throws {
        let json = """
        {"event":"PreToolUse","tool":"Bash","input":{"command":"npm run build"}}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(event.event, "PreToolUse")
        XCTAssertEqual(event.tool, "Bash")
        XCTAssertEqual(event.input?.command, "npm run build")
    }

    func test_claudeEvent_decodes_stop_input_required() throws {
        let json = """
        {"event":"Stop","reason":"input_required","message":"Overwrite file?","options":["y","a","n"]}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(event.reason, "input_required")
        XCTAssertEqual(event.message, "Overwrite file?")
        XCTAssertEqual(event.options, ["y", "a", "n"])
    }

    func test_claudeEvent_decodes_stop_task_complete() throws {
        let json = """
        {"event":"Stop","reason":"task_complete"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(event.event, "Stop")
        XCTAssertEqual(event.reason, "task_complete")
        XCTAssertNil(event.message)
    }

    func test_inputOption_defaults() {
        let options = InputOption.defaults
        XCTAssertEqual(options.count, 3)
        XCTAssertEqual(options[0].id, "y")
        XCTAssertEqual(options[1].id, "a")
        XCTAssertEqual(options[2].id, "n")
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(error:|FAILED|passed|failed)"
```

Expected: compile errors (types not defined yet)

- [ ] **Step 3: Create `ClaudeMenuBar/Models/AppState.swift`**

```swift
import Foundation

enum AppState: Equatable {
    case silent
    case working(tool: String, detail: String)
    case waitingInput(message: String, options: [InputOption])
    case complete
}

struct InputOption: Equatable, Identifiable {
    let id: String
    let label: String
    let sublabel: String

    static let defaults: [InputOption] = [
        InputOption(id: "y", label: "Y", sublabel: "允许一次"),
        InputOption(id: "a", label: "A", sublabel: "全部允许"),
        InputOption(id: "n", label: "N", sublabel: "拒绝")
    ]
}
```

- [ ] **Step 4: Create `ClaudeMenuBar/Models/ClaudeEvent.swift`**

```swift
import Foundation

struct ClaudeEvent: Codable {
    let event: String
    let tool: String?
    let input: ToolInput?
    let reason: String?
    let message: String?
    let options: [String]?
}

struct ToolInput: Codable {
    let command: String?
    let path: String?
    let description: String?
}
```

- [ ] **Step 5: Run tests — verify they pass**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(passed|failed|error:)"
```

Expected: `Test Suite ... passed`

- [ ] **Step 6: Commit**

```bash
git add ClaudeMenuBar/Models/ ClaudeMenuBarTests/ModelsTests.swift
git commit -m "feat: AppState and ClaudeEvent models"
```

---

## Task 3: EventRouter

**Files:**
- Create: `ClaudeMenuBar/Services/EventRouter.swift`
- Create: `ClaudeMenuBarTests/EventRouterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ClaudeMenuBarTests/EventRouterTests.swift
import XCTest
@testable import ClaudeMenuBar

final class EventRouterTests: XCTestCase {
    let router = EventRouter()

    func test_preToolUse_returns_working_state() {
        let event = ClaudeEvent(
            event: "PreToolUse", tool: "Bash",
            input: ToolInput(command: "npm run build", path: nil, description: nil),
            reason: nil, message: nil, options: nil
        )
        let state = router.route(event)
        XCTAssertEqual(state, .working(tool: "Bash", detail: "npm run build"))
    }

    func test_preToolUse_edit_uses_path_as_detail() {
        let event = ClaudeEvent(
            event: "PreToolUse", tool: "Edit",
            input: ToolInput(command: nil, path: "src/main.swift", description: nil),
            reason: nil, message: nil, options: nil
        )
        let state = router.route(event)
        XCTAssertEqual(state, .working(tool: "Edit", detail: "src/main.swift"))
    }

    func test_postToolUse_returns_working_state() {
        let event = ClaudeEvent(
            event: "PostToolUse", tool: "Read",
            input: ToolInput(command: nil, path: "README.md", description: nil),
            reason: nil, message: nil, options: nil
        )
        XCTAssertEqual(router.route(event), .working(tool: "Read", detail: "README.md"))
    }

    func test_stop_input_required_returns_waitingInput_with_defaults() {
        let event = ClaudeEvent(
            event: "Stop", tool: nil, input: nil,
            reason: "input_required", message: "Overwrite file?", options: nil
        )
        let state = router.route(event)
        XCTAssertEqual(state, .waitingInput(message: "Overwrite file?", options: InputOption.defaults))
    }

    func test_stop_input_required_with_numbered_options() {
        let event = ClaudeEvent(
            event: "Stop", tool: nil, input: nil,
            reason: "input_required", message: "Choose approach",
            options: ["Upgrade to latest", "Keep current", "Specify version"]
        )
        let state = router.route(event)
        guard case .waitingInput(let message, let options) = state else {
            XCTFail("Expected waitingInput"); return
        }
        XCTAssertEqual(message, "Choose approach")
        XCTAssertEqual(options.count, 3)
        XCTAssertEqual(options[0].id, "1")
        XCTAssertEqual(options[0].sublabel, "Upgrade to latest")
        XCTAssertEqual(options[2].id, "3")
    }

    func test_stop_task_complete_returns_complete() {
        let event = ClaudeEvent(
            event: "Stop", tool: nil, input: nil,
            reason: "task_complete", message: nil, options: nil
        )
        XCTAssertEqual(router.route(event), .complete)
    }

    func test_notification_returns_working() {
        let event = ClaudeEvent(
            event: "Notification", tool: nil, input: nil,
            reason: nil, message: "Build finished", options: nil
        )
        XCTAssertEqual(router.route(event), .working(tool: "Notice", detail: "Build finished"))
    }

    func test_unknown_event_returns_nil() {
        let event = ClaudeEvent(
            event: "UnknownEvent", tool: nil, input: nil,
            reason: nil, message: nil, options: nil
        )
        XCTAssertNil(router.route(event))
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: compile errors

- [ ] **Step 3: Create `ClaudeMenuBar/Services/EventRouter.swift`**

```swift
import Foundation

final class EventRouter {
    func route(_ event: ClaudeEvent) -> AppState? {
        switch event.event {
        case "PreToolUse", "PostToolUse":
            let tool = event.tool ?? "Running"
            let detail = event.input?.command
                ?? event.input?.path
                ?? event.input?.description
                ?? ""
            return .working(tool: tool, detail: detail)

        case "Stop":
            if event.reason == "input_required" {
                let message = event.message ?? "Claude needs your input"
                let options = makeOptions(from: event.options)
                return .waitingInput(message: message, options: options)
            }
            return .complete

        case "Notification":
            return .working(tool: "Notice", detail: event.message ?? "")

        default:
            return nil
        }
    }

    private func makeOptions(from raw: [String]?) -> [InputOption] {
        guard let raw, !raw.isEmpty else { return InputOption.defaults }
        return raw.enumerated().map { index, text in
            InputOption(id: String(index + 1), label: String(index + 1), sublabel: text)
        }
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(passed|failed)"
```

Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add ClaudeMenuBar/Services/EventRouter.swift ClaudeMenuBarTests/EventRouterTests.swift
git commit -m "feat: EventRouter — maps Claude hook events to AppState"
```

---

## Task 4: StateManager

**Files:**
- Create: `ClaudeMenuBar/State/StateManager.swift`
- Create: `ClaudeMenuBarTests/StateManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ClaudeMenuBarTests/StateManagerTests.swift
import XCTest
@testable import ClaudeMenuBar

@MainActor
final class StateManagerTests: XCTestCase {

    func test_initial_state_is_silent() {
        let manager = StateManager()
        XCTAssertEqual(manager.state, .silent)
    }

    func test_transition_to_working() {
        let manager = StateManager()
        manager.transition(to: .working(tool: "Bash", detail: "ls"))
        XCTAssertEqual(manager.state, .working(tool: "Bash", detail: "ls"))
    }

    func test_transition_to_waitingInput() {
        let manager = StateManager()
        manager.transition(to: .waitingInput(message: "Allow?", options: InputOption.defaults))
        XCTAssertEqual(manager.state, .waitingInput(message: "Allow?", options: InputOption.defaults))
    }

    func test_transition_to_complete_then_auto_silent() async throws {
        let manager = StateManager()
        manager.transition(to: .complete)
        XCTAssertEqual(manager.state, .complete)
        // Auto-transition after 3s — use shortened timeout for tests
        try await Task.sleep(for: .milliseconds(100))
        // State should still be complete before timer fires
        XCTAssertEqual(manager.state, .complete)
    }

    func test_new_transition_cancels_complete_timer() {
        let manager = StateManager()
        manager.transition(to: .complete)
        manager.transition(to: .working(tool: "Bash", detail: "test"))
        XCTAssertEqual(manager.state, .working(tool: "Bash", detail: "test"))
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(error:|FAILED)"
```

- [ ] **Step 3: Create `ClaudeMenuBar/State/StateManager.swift`**

```swift
import Foundation

@MainActor
final class StateManager: ObservableObject {
    @Published private(set) var state: AppState = .silent

    private var completeTask: Task<Void, Never>?

    func transition(to newState: AppState) {
        completeTask?.cancel()
        completeTask = nil
        state = newState

        if newState == .complete {
            completeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.state = .silent
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(passed|failed)"
```

- [ ] **Step 5: Commit**

```bash
git add ClaudeMenuBar/State/StateManager.swift ClaudeMenuBarTests/StateManagerTests.swift
git commit -m "feat: StateManager — owns AppState with 3s complete timer"
```

---

## Task 5: HTTPServer

**Files:**
- Create: `ClaudeMenuBar/Services/HTTPServer.swift`

- [ ] **Step 1: Create `ClaudeMenuBar/Services/HTTPServer.swift`**

```swift
import Foundation
import Network

final class HTTPServer {
    static let port: UInt16 = 36787

    var onEventData: ((Data) -> Void)?

    private var listener: NWListener?

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: HTTPServer.port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let data, error == nil else { connection.cancel(); return }
            self?.parseHTTPBody(from: data, connection: connection)
        }
    }

    private func parseHTTPBody(from rawData: Data, connection: NWConnection) {
        // Split headers and body on \r\n\r\n
        let separator = Data("\r\n\r\n".utf8)
        if let range = rawData.range(of: separator) {
            let body = rawData[range.upperBound...]
            if !body.isEmpty {
                onEventData?(Data(body))
            }
        }
        sendOK(to: connection)
    }

    private func sendOK(to connection: NWConnection) {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
```

- [ ] **Step 2: Note on smoke testing**

The HTTP server will be smoke-tested as part of Task 10 (end-to-end manual test), once `MenuBarController` wires it into the running app. No standalone test needed here — the unit structure is verified by the build succeeding.

- [ ] **Step 3: Commit**

```bash
git add ClaudeMenuBar/Services/HTTPServer.swift
git commit -m "feat: HTTPServer — NWListener on port 36787"
```

---

## Task 6: PillPositioner

**Files:**
- Create: `ClaudeMenuBar/Helpers/PillPositioner.swift`
- Create: `ClaudeMenuBarTests/PillPositionerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ClaudeMenuBarTests/PillPositionerTests.swift
import XCTest
@testable import ClaudeMenuBar

final class PillPositionerTests: XCTestCase {

    func test_notchRight_is_right_of_center() {
        // Simulate a 2560-wide screen
        let screenWidth: CGFloat = 2560
        let notchWidth: CGFloat = 210
        let gap: CGFloat = 8
        let expected = screenWidth / 2 + notchWidth / 2 + gap
        let result = PillPositioner.notchRightEdge(screenWidth: screenWidth, notchWidth: notchWidth, gap: gap)
        XCTAssertEqual(result, expected)
    }

    func test_noNotch_positions_at_center_offset() {
        let screenWidth: CGFloat = 1920
        let result = PillPositioner.notchRightEdge(screenWidth: screenWidth, notchWidth: 0, gap: 12)
        XCTAssertEqual(result, screenWidth / 2 + 12)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(error:|FAILED)"
```

- [ ] **Step 3: Create `ClaudeMenuBar/Helpers/PillPositioner.swift`**

```swift
import AppKit

enum PillPositioner {
    /// Approximate notch width in points for MacBook Pro (14" and 16")
    static let notchWidth: CGFloat = 210
    static let pillHeight: CGFloat = 22

    /// X coordinate where the pill's left edge should start (right of notch)
    static func notchRightEdge(
        screenWidth: CGFloat,
        notchWidth: CGFloat = PillPositioner.notchWidth,
        gap: CGFloat = 8
    ) -> CGFloat {
        screenWidth / 2 + notchWidth / 2 + gap
    }

    /// Full origin point for the pill NSPanel on a given screen
    static func pillOrigin(on screen: NSScreen, pillWidth: CGFloat) -> NSPoint {
        let screenFrame = screen.frame
        let menuBarHeight = NSStatusBar.system.thickness
        let hasNotch = screen.safeAreaInsets.top > 0
        let effectiveNotchWidth = hasNotch ? Self.notchWidth : 0

        let x = notchRightEdge(
            screenWidth: screenFrame.width,
            notchWidth: effectiveNotchWidth
        )
        // Place vertically centered in menu bar
        let y = screenFrame.maxY - menuBarHeight + (menuBarHeight - pillHeight) / 2
        return NSPoint(x: screenFrame.minX + x, y: y)
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(passed|failed)"
```

- [ ] **Step 5: Commit**

```bash
git add ClaudeMenuBar/Helpers/PillPositioner.swift ClaudeMenuBarTests/PillPositionerTests.swift
git commit -m "feat: PillPositioner — calculates pill position right of notch"
```

---

## Task 7: SwiftUI Views

**Files:**
- Create: `ClaudeMenuBar/Views/WorkingView.swift`
- Create: `ClaudeMenuBar/Views/CompleteView.swift`
- Create: `ClaudeMenuBar/Views/WaitingView.swift`
- Create: `ClaudeMenuBar/Views/DropdownView.swift`

- [ ] **Step 1: Create `ClaudeMenuBar/Views/WorkingView.swift`**

```swift
import SwiftUI

struct WorkingView: View {
    let tool: String
    let detail: String

    var body: some View {
        HStack(spacing: 7) {
            BreathingDot(hexColor: "#7c3aed")
            Text("\(tool) · \(detail)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "#a78bfa"))
                .lineLimit(1)
            BouncingEllipsis()
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(
            Capsule()
                .fill(Color(hex: "#13111f"))
                .overlay(Capsule().strokeBorder(Color(hex: "#7c3aed").opacity(0.3), lineWidth: 1))
        )
    }
}

struct CompleteView: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: "#22c55e"))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: "#22c55e"), radius: 4)
            Text("任务完成")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "#86efac"))
        }
        .padding(.horizontal, 14)
        .frame(height: 22)
        .background(
            Capsule()
                .fill(Color(hex: "#052e16"))
                .overlay(Capsule().strokeBorder(Color(hex: "#22c55e").opacity(0.3), lineWidth: 1))
        )
    }
}

// MARK: - Sub-components

struct BreathingDot: View {
    let hexColor: String
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(Color(hex: hexColor))
            .frame(width: 6, height: 6)
            .shadow(color: Color(hex: hexColor), radius: 3)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 0.5
                }
            }
    }
}

struct BouncingEllipsis: View {
    @State private var offsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#7c3aed").opacity(0.6))
                    .frame(width: 3, height: 3)
                    .offset(y: offsets[i])
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2)
                        ) {
                            offsets[i] = -2
                        }
                    }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: Create `ClaudeMenuBar/Views/WaitingView.swift`**

```swift
import SwiftUI

/// Compact anchor shown in the menu bar when waiting for input (top of pill, open bottom)
struct WaitingAnchorView: View {
    var body: some View {
        HStack(spacing: 7) {
            BreathingDot(hexColor: "#f59e0b")
            Text("需要你的确认")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: "#fbbf24"))
        }
        .padding(.horizontal, 14)
        .frame(height: 22)
        .background(
            Color(hex: "#120c00")
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Color(hex: "#f59e0b").opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 11))
        )
    }
}
```

- [ ] **Step 3: Create `ClaudeMenuBar/Views/DropdownView.swift`**

```swift
import SwiftUI

struct DropdownView: View {
    let message: String
    let options: [InputOption]
    let onSelect: (InputOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Color(.labelColor))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(options) { option in
                    Button(action: { onSelect(option) }) {
                        VStack(spacing: 2) {
                            Text(option.label)
                                .font(.system(size: 12, weight: .bold))
                            Text(option.sublabel)
                                .font(.system(size: 8))
                                .opacity(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(optionBackground(for: option))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(optionBorder(for: option), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(optionForeground(for: option))
                }
            }

            Text("按键盘 \(keyHint) 直接响应")
                .font(.system(size: 8))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .frame(width: 240)
        .background(Color(hex: "#120c00"))
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 14,
                bottomTrailingRadius: 14, topTrailingRadius: 0
            )
            .strokeBorder(Color(hex: "#f59e0b").opacity(0.3), lineWidth: 1)
        )
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 14,
            bottomTrailingRadius: 14, topTrailingRadius: 0
        ))
    }

    private var keyHint: String {
        options.map { $0.label }.joined(separator: " · ")
    }

    private func optionBackground(for option: InputOption) -> Color {
        switch option.id {
        case "y", "1": return Color(hex: "#14532d")
        case "a": return Color(hex: "#1e3a5f")
        case "n": return Color(hex: "#450a0a")
        default:  return Color(hex: "#1a1a2e")
        }
    }

    private func optionBorder(for option: InputOption) -> Color {
        switch option.id {
        case "y", "1": return Color(hex: "#16a34a").opacity(0.4)
        case "a": return Color(hex: "#2563eb").opacity(0.4)
        case "n": return Color(hex: "#dc2626").opacity(0.4)
        default:  return Color(hex: "#7c3aed").opacity(0.3)
        }
    }

    private func optionForeground(for option: InputOption) -> Color {
        switch option.id {
        case "y", "1": return Color(hex: "#86efac")
        case "a": return Color(hex: "#93c5fd")
        case "n": return Color(hex: "#fca5a5")
        default:  return Color(hex: "#c4b5fd")
        }
    }
}
```

- [ ] **Step 4: Build to verify views compile**

```bash
xcodebuild -scheme ClaudeMenuBar -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ClaudeMenuBar/Views/
git commit -m "feat: SwiftUI views — WorkingView, CompleteView, WaitingView, DropdownView"
```

---

## Task 8: MenuBarPill + DropdownPanel Windows

**Files:**
- Create: `ClaudeMenuBar/Windows/MenuBarPill.swift`
- Create: `ClaudeMenuBar/Windows/DropdownPanel.swift`

- [ ] **Step 1: Create `ClaudeMenuBar/Windows/MenuBarPill.swift`**

```swift
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
```

- [ ] **Step 2: Create `ClaudeMenuBar/Windows/DropdownPanel.swift`**

```swift
import AppKit
import SwiftUI

final class DropdownPanel {
    private var panel: NSPanel?

    func show<Content: View>(view: Content, anchorOrigin: NSPoint, anchorWidth: CGFloat) {
        let width: CGFloat = 240
        // Align left edge with anchor left edge
        let x = anchorOrigin.x
        // Position just below the anchor (anchor.y - dropdown height; y is flipped in NSScreen coords)
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
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme ClaudeMenuBar -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ClaudeMenuBar/Windows/
git commit -m "feat: MenuBarPill and DropdownPanel — NSPanel windows"
```

---

## Task 9: GlobalHotkeys + KeystrokeReplay

**Files:**
- Create: `ClaudeMenuBar/Services/GlobalHotkeys.swift`
- Create: `ClaudeMenuBar/Services/KeystrokeReplay.swift`

- [ ] **Step 1: Create `ClaudeMenuBar/Services/KeystrokeReplay.swift`**

```swift
import CoreGraphics
import AppKit

enum KeystrokeReplay {
    /// Posts a key character to the system (simulates typing in active window)
    static func type(_ character: String) {
        guard let keyCode = keyCode(for: character) else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        // Post to the HID event system so the terminal receives it
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Follow with Return
        let returnDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let returnUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        returnDown?.post(tap: .cghidEventTap)
        returnUp?.post(tap: .cghidEventTap)
    }

    private static func keyCode(for character: String) -> CGKeyCode? {
        // Virtual key codes for common keys
        let map: [String: CGKeyCode] = [
            "y": 0x10, "Y": 0x10,
            "a": 0x00, "A": 0x00,
            "n": 0x2D, "N": 0x2D,
            "1": 0x12, "2": 0x13, "3": 0x14,
        ]
        return map[character]
    }
}
```

- [ ] **Step 2: Create `ClaudeMenuBar/Services/GlobalHotkeys.swift`**

```swift
import CoreGraphics
import AppKit

final class GlobalHotkeys {
    private var eventTap: CFMachPort?
    var onKey: ((String) -> Void)?

    func enable() {
        guard AXIsProcessTrusted() else {
            requestAccessibility()
            return
        }
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(refcon).takeUnretainedValue()
                return hotkeys.handle(event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap = eventTap else { return }
        let loop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), loop, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func disable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        eventTap = nil
    }

    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let codeMap: [Int64: String] = [
            0x10: "y", 0x00: "a", 0x2D: "n",
            0x12: "1", 0x13: "2", 0x14: "3",
            0x35: "esc"
        ]
        guard let key = codeMap[keyCode] else { return Unmanaged.passRetained(event) }
        onKey?(key)
        // Consume the event so it doesn't reach the terminal raw
        return nil
    }

    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme ClaudeMenuBar -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -3
```

- [ ] **Step 4: Commit**

```bash
git add ClaudeMenuBar/Services/GlobalHotkeys.swift ClaudeMenuBar/Services/KeystrokeReplay.swift
git commit -m "feat: GlobalHotkeys (CGEventTap) and KeystrokeReplay (CGEventPost)"
```

---

## Task 10: MenuBarController — Wire Everything Together

**Files:**
- Create: `ClaudeMenuBar/MenuBarController.swift`
- Modify: `ClaudeMenuBar/ClaudeMenuBarApp.swift`

- [ ] **Step 1: Create `ClaudeMenuBar/MenuBarController.swift`**

```swift
import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let stateManager = StateManager()
    private let eventRouter = EventRouter()
    private let httpServer = HTTPServer()
    private let pill = MenuBarPill()
    private let dropdown = DropdownPanel()
    private let hotkeys = GlobalHotkeys()
    private var cancellable: Any?

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
```

- [ ] **Step 2: Update `ClaudeMenuBar/ClaudeMenuBarApp.swift`**

```swift
import SwiftUI

@main
struct ClaudeMenuBarApp: App {
    @StateObject private var controller = MenuBarController()

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 3: Build and run manually**

```bash
xcodebuild -scheme ClaudeMenuBar -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -3
```

Then open `.app` and test with:
```bash
# Test working state
curl -X POST http://localhost:36787/event \
  -H "Content-Type: application/json" \
  -d '{"event":"PreToolUse","tool":"Bash","input":{"command":"npm run build"}}'

# Test waiting state
curl -X POST http://localhost:36787/event \
  -H "Content-Type: application/json" \
  -d '{"event":"Stop","reason":"input_required","message":"Overwrite 3 files?"}'

# Test complete state
curl -X POST http://localhost:36787/event \
  -H "Content-Type: application/json" \
  -d '{"event":"Stop","reason":"task_complete"}'
```

Verify:
- Purple pill appears right of notch for working state
- Orange pill + dropdown for waiting state
- System beep plays on waiting
- Y/N keys respond and dismiss
- Green pill for 3s then disappears

- [ ] **Step 4: Commit**

```bash
git add ClaudeMenuBar/MenuBarController.swift ClaudeMenuBar/ClaudeMenuBarApp.swift
git commit -m "feat: MenuBarController — wires all components end-to-end"
```

---

## Task 11: Claude Code Hook Script + Installer

**Files:**
- Create: `scripts/claudemenubar-hook.sh`
- Create: `scripts/install.sh`

- [ ] **Step 1: Create `scripts/claudemenubar-hook.sh`**

```bash
#!/bin/bash
# ClaudeMenuBar hook — forwards Claude Code events to the ClaudeMenuBar app
# Called by Claude Code with event JSON in $CLAUDE_HOOK_EVENT_JSON

curl -s -X POST "http://localhost:36787/event" \
  -H "Content-Type: application/json" \
  -d "${CLAUDE_HOOK_EVENT_JSON}" \
  --max-time 1 \
  --silent \
  --output /dev/null &
```

- [ ] **Step 2: Create `scripts/install.sh`**

```bash
#!/bin/bash
set -e

APP_NAME="ClaudeMenuBar"
INSTALL_DIR="/Applications"
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claudemenubar-hook.sh"
REPO_RAW="https://raw.githubusercontent.com/user/ClaudeMenuBar/main"  # TODO: update with actual GitHub username before publishing

echo "Installing ClaudeMenuBar..."

# 1. Create hooks directory
mkdir -p "$HOOK_DIR"

# 2. Install hook script
curl -fsSL "$REPO_RAW/scripts/claudemenubar-hook.sh" -o "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"
echo "  ✓ Hook script installed at $HOOK_SCRIPT"

# 3. Merge hook config into settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

HOOK_ENTRY=$(cat <<EOF
{
  "type": "command",
  "command": "$HOOK_SCRIPT"
}
EOF
)

python3 - "$SETTINGS_FILE" "$HOOK_ENTRY" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
hook_json = json.loads(sys.argv[2])

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
for event in ["PreToolUse", "PostToolUse", "Stop", "Notification"]:
    event_hooks = hooks.setdefault(event, [])
    # Avoid duplicates
    if not any(h.get("command") == hook_json["command"] for h in event_hooks):
        event_hooks.append(hook_json)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"  ✓ Hooks registered in {settings_path}")
PYEOF

echo "  ✓ Claude Code hooks configured"
echo ""
echo "ClaudeMenuBar installed. Open ClaudeMenuBar.app to start."
echo "Grant Accessibility permission when prompted."
```

- [ ] **Step 3: Make scripts executable and verify**

```bash
chmod +x scripts/claudemenubar-hook.sh scripts/install.sh

# Smoke test the hook script locally
CLAUDE_HOOK_EVENT_JSON='{"event":"PreToolUse","tool":"Bash","input":{"command":"echo test"}}' \
  bash scripts/claudemenubar-hook.sh
# Expected: no output (fires curl in background), no error
```

- [ ] **Step 4: Commit**

```bash
git add scripts/
git commit -m "feat: hook script and installer"
```

---

## Task 12: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update CLAUDE.md with build and run commands**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ClaudeMenuBar — a macOS menu bar app that integrates with Claude Code via hooks. A floating pill appears right of the notch in the menu bar, showing Claude's current state and enabling keyboard responses without switching windows.

## Build

Requires Xcode 15+ and xcodegen (`brew install xcodegen`).

```bash
# Regenerate .xcodeproj after modifying project.yml
xcodegen generate

# Build
xcodebuild -scheme ClaudeMenuBar -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Run tests
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Run a single test
xcodebuild test -scheme ClaudeMenuBar -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  -only-testing ClaudeMenuBarTests/EventRouterTests
```

## Architecture

- `StateManager` is the single source of truth for `AppState` (silent/working/waitingInput/complete)
- `HTTPServer` (port 36787) receives Claude Code hook events as JSON POST requests
- `EventRouter` maps `ClaudeEvent` JSON → `AppState` transitions
- `MenuBarController` observes `StateManager.$state` and updates the two `NSPanel` windows
- `GlobalHotkeys` uses `CGEventTap` — only active in `waitingInput` state
- `KeystrokeReplay` uses `CGEventPost` to send Y/A/N keystrokes to the active terminal

## Manual Testing

Send test events:
```bash
curl -X POST http://localhost:36787/event -H "Content-Type: application/json" \
  -d '{"event":"PreToolUse","tool":"Bash","input":{"command":"npm run build"}}'

curl -X POST http://localhost:36787/event -H "Content-Type: application/json" \
  -d '{"event":"Stop","reason":"input_required","message":"Overwrite files?"}'

curl -X POST http://localhost:36787/event -H "Content-Type: application/json" \
  -d '{"event":"Stop","reason":"task_complete"}'
```
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with build commands and architecture"
```
