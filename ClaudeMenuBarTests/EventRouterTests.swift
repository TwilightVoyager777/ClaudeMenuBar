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
        XCTAssertEqual(router.route(event), .working(tool: "Bash", detail: "npm run build"))
    }

    func test_preToolUse_edit_uses_path_as_detail() {
        let event = ClaudeEvent(
            event: "PreToolUse", tool: "Edit",
            input: ToolInput(command: nil, path: "src/main.swift", description: nil),
            reason: nil, message: nil, options: nil
        )
        XCTAssertEqual(router.route(event), .working(tool: "Edit", detail: "src/main.swift"))
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
        XCTAssertEqual(router.route(event), .waitingInput(message: "Overwrite file?", options: InputOption.defaults))
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
