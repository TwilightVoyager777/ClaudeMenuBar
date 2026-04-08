import Foundation

final class EventRouter {
    func route(_ event: ClaudeEvent) -> AppState? {
        switch event.event {

        case "PreToolUse":
            let tool = event.tool ?? "Running"
            let detail = event.input?.command
                ?? event.input?.filePath
                ?? event.input?.path
                ?? event.input?.description
                ?? ""
            return .working(tool: tool, detail: detail)

        case "PostToolUse":
            // Tool finished; leave the current working state visible until
            // the next PreToolUse or Stop arrives.
            return nil

        case "Stop":
            // Claude Code Stop carries no stop_reason — it simply fires when
            // the turn ends normally.
            return .complete

        case "StopFailure":
            // Turn ended due to API error; clear the UI without a Done banner.
            return .silent

        case "PermissionRequest":
            // Claude is asking for permission to run a tool.
            let tool = event.tool ?? "Tool"
            let detail = event.input?.command
                ?? event.input?.filePath
                ?? event.input?.path
                ?? ""
            let message: String
            if detail.isEmpty {
                message = "Allow \(tool)?"
            } else if detail.count > 80 {
                message = "Allow \(tool)?\nContent is too long — check terminal for details."
            } else {
                message = "Allow \(tool): \(detail)"
            }
            let options = (event.permissionSuggestions?.isEmpty == false)
                ? InputOption.defaults
                : InputOption.yesNo
            return .waitingInput(message: message, options: options)

        case "Notification":
            return .working(tool: "Notice", detail: event.message ?? "")

        default:
            return nil
        }
    }
}
