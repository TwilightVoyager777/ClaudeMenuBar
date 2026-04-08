import Foundation

final class EventRouter {
    func route(_ event: ClaudeEvent) -> AppState? {
        switch event.event {
        case "PreToolUse":
            let tool = event.tool ?? "Running"
            let detail = event.input?.command
                ?? event.input?.path
                ?? event.input?.description
                ?? ""
            return .working(tool: tool, detail: detail)

        case "PostToolUse":
            // Tool has finished; keep the current working state visible until
            // the next PreToolUse or Stop arrives. Returning nil leaves the
            // existing state unchanged.
            return nil

        case "Stop":
            switch event.reason {
            case "input_required":
                let message = event.message ?? "Claude needs your input"
                return .waitingInput(message: message, options: makeOptions(from: event.options))
            case "task_complete":
                return .complete
            default:
                // error, cancelled, unknown future reasons — clear UI without
                // showing a false "Done" banner
                return .silent
            }

        case "Notification":
            return .working(tool: "Notice", detail: event.message ?? "")

        default:
            return nil
        }
    }

    private func makeOptions(from raw: [String]?) -> [InputOption] {
        guard let raw, !raw.isEmpty else { return InputOption.defaults }
        return raw.enumerated().map { index, text in
            InputOption(id: String(index + 1), label: String(index + 1), sublabel: text)
        }
    }
}
