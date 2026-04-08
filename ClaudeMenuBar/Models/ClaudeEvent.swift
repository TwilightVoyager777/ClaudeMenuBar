import Foundation

struct ClaudeEvent: Codable {
    let event: String
    let tool: String?
    let input: ToolInput?
    let message: String?
    let options: [String]?

    enum CodingKeys: String, CodingKey {
        case event = "hook_event_name"
        case tool = "tool_name"
        case input = "tool_input"
        case message
        case options
    }
}

struct ToolInput: Codable {
    let command: String?
    let filePath: String?   // Write / Edit / Read use file_path
    let path: String?       // Glob / Grep use path
    let description: String?

    enum CodingKeys: String, CodingKey {
        case command
        case filePath = "file_path"
        case path
        case description
    }
}
