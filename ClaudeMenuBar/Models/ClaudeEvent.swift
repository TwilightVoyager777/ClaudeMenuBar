import Foundation

struct ClaudeEvent: Codable {
    let event: String
    let tool: String?
    let input: ToolInput?
    let message: String?
    let options: [String]?
    /// True when the payload contains a non-empty permission_suggestions array.
    let hasPermissionSuggestions: Bool

    /// Memberwise-init with defaults so tests can omit fields they don't care about.
    init(event: String, tool: String? = nil, input: ToolInput? = nil,
         message: String? = nil, options: [String]? = nil,
         hasPermissionSuggestions: Bool = false) {
        self.event = event
        self.tool = tool
        self.input = input
        self.message = message
        self.options = options
        self.hasPermissionSuggestions = hasPermissionSuggestions
    }

    enum CodingKeys: String, CodingKey {
        case event = "hook_event_name"
        case tool = "tool_name"
        case input = "tool_input"
        case message
        case options
        case permissionSuggestions = "permission_suggestions"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        event = try c.decode(String.self, forKey: .event)
        tool = try c.decodeIfPresent(String.self, forKey: .tool)
        input = try c.decodeIfPresent(ToolInput.self, forKey: .input)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        options = try c.decodeIfPresent([String].self, forKey: .options)
        // Only check existence — the actual structure varies and we don't need its contents.
        hasPermissionSuggestions = c.contains(.permissionSuggestions)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(event, forKey: .event)
        try c.encodeIfPresent(tool, forKey: .tool)
        try c.encodeIfPresent(input, forKey: .input)
        try c.encodeIfPresent(message, forKey: .message)
        try c.encodeIfPresent(options, forKey: .options)
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
