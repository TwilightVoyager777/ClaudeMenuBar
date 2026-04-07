import Foundation

struct ClaudeEvent: Codable {
    let event: String
    let tool: String?
    let input: ToolInput?
    let reason: String?
    let message: String?
    let options: [String]?
}

struct ToolInput: Codable {
    let command: String?
    let path: String?
    let description: String?
}
