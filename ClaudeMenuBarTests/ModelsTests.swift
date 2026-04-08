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

    // MARK: - Real Claude Code payloads (hook_event_name on stdin)

    func test_decodes_preToolUse_with_command() throws {
        let json = """
        {"hook_event_name":"PreToolUse","tool_name":"Bash",
         "tool_input":{"command":"npm run build"}}
        """.data(using: .utf8)!
        let e = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(e.event, "PreToolUse")
        XCTAssertEqual(e.tool, "Bash")
        XCTAssertEqual(e.input?.command, "npm run build")
    }

    func test_decodes_preToolUse_with_file_path() throws {
        // Write / Edit / Read use file_path, not path
        let json = """
        {"hook_event_name":"PreToolUse","tool_name":"Write",
         "tool_input":{"file_path":"/src/main.swift","content":"..."}}
        """.data(using: .utf8)!
        let e = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(e.tool, "Write")
        XCTAssertEqual(e.input?.filePath, "/src/main.swift")
        XCTAssertNil(e.input?.command)
    }

    func test_decodes_stop_has_no_stop_reason() throws {
        // Real Claude Code Stop payload carries no stop_reason field
        let json = """
        {"hook_event_name":"Stop","session_id":"abc","cwd":"/tmp","permission_mode":"default"}
        """.data(using: .utf8)!
        let e = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(e.event, "Stop")
        XCTAssertNil(e.message)
        XCTAssertNil(e.options)
    }

    func test_decodes_permissionRequest() throws {
        let json = """
        {"hook_event_name":"PermissionRequest","tool_name":"Bash",
         "tool_input":{"command":"rm -rf node_modules"}}
        """.data(using: .utf8)!
        let e = try JSONDecoder().decode(ClaudeEvent.self, from: json)
        XCTAssertEqual(e.event, "PermissionRequest")
        XCTAssertEqual(e.tool, "Bash")
        XCTAssertEqual(e.input?.command, "rm -rf node_modules")
    }

    func test_inputOption_defaults() {
        let options = InputOption.defaults
        XCTAssertEqual(options.count, 3)
        XCTAssertEqual(options[0].id, "y")
        XCTAssertEqual(options[1].id, "a")
        XCTAssertEqual(options[2].id, "n")
    }
}
