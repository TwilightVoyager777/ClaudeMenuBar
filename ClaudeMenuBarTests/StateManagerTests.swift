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

    func test_complete_does_not_auto_dismiss_immediately() async throws {
        let manager = StateManager(completeDismissDelay: 0.2)
        manager.transition(to: .complete)
        XCTAssertEqual(manager.state, .complete)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(manager.state, .complete, "Should still be .complete before delay elapses")
    }

    func test_complete_auto_dismisses_after_delay() async throws {
        let manager = StateManager(completeDismissDelay: 0.05)
        manager.transition(to: .complete)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(manager.state, .silent, "Should auto-dismiss to .silent after delay")
    }

    func test_waitingInput_ignores_working_transition() {
        let manager = StateManager()
        manager.transition(to: .waitingInput(message: "Allow?", options: InputOption.defaults))
        manager.transition(to: .working(tool: "Bash", detail: "ls"))
        XCTAssertEqual(manager.state, .waitingInput(message: "Allow?", options: InputOption.defaults),
                       "working events should not dismiss waitingInput")
    }

    func test_waitingInput_allows_silent_transition() {
        let manager = StateManager()
        manager.transition(to: .waitingInput(message: "Allow?", options: InputOption.defaults))
        manager.transition(to: .silent)
        XCTAssertEqual(manager.state, .silent)
    }

    func test_waitingInput_allows_complete_transition() {
        let manager = StateManager()
        manager.transition(to: .waitingInput(message: "Allow?", options: InputOption.defaults))
        manager.transition(to: .complete)
        XCTAssertEqual(manager.state, .complete)
    }

    func test_new_transition_cancels_auto_dismiss_timer() async throws {
        let manager = StateManager(completeDismissDelay: 0.05)
        manager.transition(to: .complete)
        manager.transition(to: .working(tool: "Bash", detail: "test"))
        try await Task.sleep(for: .milliseconds(200))
        // Timer was cancelled; should still be .working, not .silent
        XCTAssertEqual(manager.state, .working(tool: "Bash", detail: "test"))
    }
}
