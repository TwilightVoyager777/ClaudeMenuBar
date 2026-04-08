import Foundation

struct ClaudeEvent: Codable {
    let event: String
    let tool: String?
    let input: ToolInput?
    let message: String?
    let options: [String]?
    let permissionSuggestions: [[String: String]]?  // swiftlint:disable:this discouraged_optional_collection

    /// Memberwise-init with defaults so tests can omit fields they don't care about.
    init(event: String, tool: String? = nil, input: ToolInput? = nil,
         message: String? = nil, options: [String]? = nil,
         permissionSuggestions: [[String: String]]? = nil) {
        self.event = event
        self.tool = tool
        self.input = input
        self.message = message
        self.options = options
        self.permissionSuggestions = permissionSuggestions
    }

    enum CodingKeys: String, CodingKey {
        case event = "hook_event_name"
        case tool = "tool_name"
        case input = "tool_input"
        case message
        case options
        case permissionSuggestions = "permission_suggestions"
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
