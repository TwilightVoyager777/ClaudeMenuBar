import Foundation

@MainActor
final class StateManager: ObservableObject {
    @Published private(set) var state: AppState = .silent

    private let completeDismissDelay: Double
    private let waitingInputDismissDelay: Double
    private var autoTransitionTask: Task<Void, Never>?

    /// Production init uses sensible defaults.
    /// Tests can inject shorter delays to avoid slow assertions.
    init(completeDismissDelay: Double = 3, waitingInputDismissDelay: Double = 300) {
        self.completeDismissDelay = completeDismissDelay
        self.waitingInputDismissDelay = waitingInputDismissDelay
    }

    func transition(to newState: AppState) {
        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        state = newState

        switch newState {
        case .complete:
            schedule(after: completeDismissDelay)
        case .waitingInput:
            schedule(after: waitingInputDismissDelay)
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
