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
