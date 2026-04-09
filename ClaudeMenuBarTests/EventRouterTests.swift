import XCTest
@testable import ClaudeMenuBar

final class EventRouterTests: XCTestCase {
    let router = EventRouter()

    // MARK: - PreToolUse

    func test_preToolUse_bash_uses_command() {
        let e = ClaudeEvent(event: "PreToolUse", tool: "Bash",
                            input: ToolInput(command: "npm run build", filePath: nil, path: nil, description: nil),
                            message: nil, options: nil)
        XCTAssertEqual(router.route(e), .working(tool: "Bash", detail: "npm run build"))
    }

    func test_preToolUse_write_uses_filePath() {
        // Write / Edit / Read use file_path in real payloads
        let e = ClaudeEvent(event: "PreToolUse", tool: "Write",
                            input: ToolInput(command: nil, filePath: "/src/main.swift", path: nil, description: nil),
                            message: nil, options: nil)
        XCTAssertEqual(router.route(e), .working(tool: "Write", detail: "/src/main.swift"))
    }

    func test_preToolUse_glob_uses_path() {
        let e = ClaudeEvent(event: "PreToolUse", tool: "Glob",
                            input: ToolInput(command: nil, filePath: nil, path: "src/**/*.swift", description: nil),
                            message: nil, options: nil)
        XCTAssertEqual(router.route(e), .working(tool: "Glob", detail: "src/**/*.swift"))
    }

    // MARK: - PostToolUse

    func test_postToolUse_returns_nil() {
        // PostToolUse = tool finished; preserve existing working state until Stop/next PreToolUse
        let e = ClaudeEvent(event: "PostToolUse", tool: "Read",
                            input: ToolInput(command: nil, filePath: "README.md", path: nil, description: nil),
                            message: nil, options: nil)
        XCTAssertNil(router.route(e))
    }

    // MARK: - Stop

    func test_stop_returns_complete_regardless_of_missing_reason() {
        // Real Claude Code Stop has no stop_reason field — always means turn complete
        let e = ClaudeEvent(event: "Stop", tool: nil, input: nil,
                            message: nil, options: nil)
        XCTAssertEqual(router.route(e), .complete)
    }

    // MARK: - StopFailure

    func test_stopFailure_returns_silent() {
        let e = ClaudeEvent(event: "StopFailure", tool: nil, input: nil,
                            message: nil, options: nil)
        XCTAssertEqual(router.route(e), .silent)
    }

    // MARK: - PermissionRequest

    func test_permissionRequest_with_suggestions_returns_3options() {
        let e = ClaudeEvent(event: "PermissionRequest", tool: "Bash",
                            input: ToolInput(command: "rm -rf node_modules", filePath: nil, path: nil, description: nil),
                            hasPermissionSuggestions: true)
        guard case .waitingInput(let message, let options) = router.route(e) else {
            XCTFail("Expected .waitingInput"); return
        }
        XCTAssertTrue(message.contains("Bash"))
        XCTAssertTrue(message.contains("rm -rf node_modules"))
        XCTAssertEqual(options, InputOption.defaults)
    }

    func test_permissionRequest_without_suggestions_returns_2options() {
        let e = ClaudeEvent(event: "PermissionRequest", tool: "Bash",
                            input: ToolInput(command: "npm install", filePath: nil, path: nil, description: nil))
        guard case .waitingInput(_, let options) = router.route(e) else {
            XCTFail("Expected .waitingInput"); return
        }
        XCTAssertEqual(options, InputOption.yesNo)
    }

    func test_permissionRequest_with_filePath_returns_waitingInput() {
        let e = ClaudeEvent(event: "PermissionRequest", tool: "Write",
                            input: ToolInput(command: nil, filePath: "/etc/hosts", path: nil, description: nil),
                            hasPermissionSuggestions: true)
        guard case .waitingInput(let message, _) = router.route(e) else {
            XCTFail("Expected .waitingInput"); return
        }
        XCTAssertTrue(message.contains("Write"))
        XCTAssertTrue(message.contains("/etc/hosts"))
    }

    func test_permissionRequest_no_detail_shows_tool_only() {
        let e = ClaudeEvent(event: "PermissionRequest", tool: "Bash")
        guard case .waitingInput(let message, _) = router.route(e) else {
            XCTFail("Expected .waitingInput"); return
        }
        XCTAssertEqual(message, "Allow Bash?")
    }

    func test_permissionRequest_long_detail_truncates() {
        let long = String(repeating: "x", count: 100)
        let e = ClaudeEvent(event: "PermissionRequest", tool: "Bash",
                            input: ToolInput(command: long, filePath: nil, path: nil, description: nil))
        guard case .waitingInput(let message, _) = router.route(e) else {
            XCTFail("Expected .waitingInput"); return
        }
        XCTAssertTrue(message.contains("too long"))
    }

    // MARK: - Notification

    func test_notification_returns_working() {
        let e = ClaudeEvent(event: "Notification", tool: nil, input: nil,
                            message: "Build finished", options: nil)
        XCTAssertEqual(router.route(e), .working(tool: "Notice", detail: "Build finished"))
    }

    func test_unknown_event_returns_nil() {
        let e = ClaudeEvent(event: "UnknownEvent", tool: nil, input: nil,
                            message: nil, options: nil)
        XCTAssertNil(router.route(e))
    }
}
