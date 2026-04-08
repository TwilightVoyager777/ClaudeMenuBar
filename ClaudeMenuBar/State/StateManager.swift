import Foundation

@MainActor
final class StateManager: ObservableObject {
    @Published private(set) var state: AppState = .silent

    private var autoTransitionTask: Task<Void, Never>?

    func transition(to newState: AppState) {
        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        state = newState

        switch newState {
        case .complete:
            // Auto-dismiss after 3 s
            schedule(after: 3)

        case .waitingInput:
            // Auto-dismiss after 5 min so it never hangs forever
            schedule(after: 300)

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
