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

    // JSON uses the real Claude Code field names (hook_event_name / tool_name /
    // tool_input / stop_reason) as mapped by CodingKeys.
    func test_claudeEvent_decodes_preToolUse() throws {
        let json = """
        {"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm run build"}}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(event.event, "PreToolUse")
        XCTAssertEqual(event.tool, "Bash")
        XCTAssertEqual(event.input?.command, "npm run build")
    }

    func test_claudeEvent_decodes_stop_input_required() throws {
        let json = """
        {"hook_event_name":"Stop","stop_reason":"input_required","message":"Overwrite file?","options":["y","a","n"]}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(event.reason, "input_required")
        XCTAssertEqual(event.message, "Overwrite file?")
        XCTAssertEqual(event.options, ["y", "a", "n"])
    }

    func test_claudeEvent_decodes_stop_task_complete() throws {
        let json = """
        {"hook_event_name":"Stop","stop_reason":"task_complete"}
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
