import Foundation

struct ClaudeEvent: Codable {
    let event: String
    let tool: String?
    let input: ToolInput?
    let reason: String?
    let message: String?
    let options: [String]?

    enum CodingKeys: String, CodingKey {
        case event = "hook_event_name"
        case tool = "tool_name"
        case input = "tool_input"
        case reason = "stop_reason"
        case message
        case options
    }
}

struct ToolInput: Codable {
    let command: String?
    let path: String?
    let description: String?
}
