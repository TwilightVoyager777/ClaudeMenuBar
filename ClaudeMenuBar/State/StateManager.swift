import Foundation

@MainActor
final class StateManager: ObservableObject {
    @Published private(set) var state: AppState = .silent

    private let completeDismissDelay: Double
    private var autoTransitionTask: Task<Void, Never>?

    /// Production init uses sensible defaults.
    /// Tests can inject shorter delays to avoid slow assertions.
    init(completeDismissDelay: Double = 3) {
        self.completeDismissDelay = completeDismissDelay
    }

    func transition(to newState: AppState) {
        // While waiting for user input, only allow transitions from explicit
        // user actions (.silent via respondWith/Esc) or session end (.complete).
        // Ignore transient events like PreToolUse/Notification so the dropdown
        // stays visible until the user responds.
        if case .waitingInput = state {
            switch newState {
            case .working:
                return
            case .silent, .complete, .waitingInput:
                break
            }
        }

        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        state = newState

        switch newState {
        case .complete:
            schedule(after: completeDismissDelay)
        default:
            break
        }
    }

    private func schedule(after seconds: Double) {
        autoTransitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.state = .silent
        }
    }
}
