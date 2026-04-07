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
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(manager.state, .complete)
    }

    func test_new_transition_cancels_complete_timer() {
        let manager = StateManager()
        manager.transition(to: .complete)
        manager.transition(to: .working(tool: "Bash", detail: "test"))
        XCTAssertEqual(manager.state, .working(tool: "Bash", detail: "test"))
    }
}
