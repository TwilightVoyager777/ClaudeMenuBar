import Foundation

final class EventRouter {
    func route(_ event: ClaudeEvent) -> AppState? {
        switch event.event {
        case "PreToolUse", "PostToolUse":
            let tool = event.tool ?? "Running"
            let detail = event.input?.command
                ?? event.input?.path
                ?? event.input?.description
                ?? ""
            return .working(tool: tool, detail: detail)

        case "Stop":
            if event.reason == "input_required" {
                let message = event.message ?? "Claude needs your input"
                let options = makeOptions(from: event.options)
                return .waitingInput(message: message, options: options)
            }
            return .complete

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
