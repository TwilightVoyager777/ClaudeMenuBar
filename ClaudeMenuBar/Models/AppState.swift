import Foundation

enum AppState: Equatable {
    case silent
    case working(tool: String, detail: String)
    case waitingInput(message: String, options: [InputOption])
    case complete
}

struct InputOption: Equatable, Identifiable {
    let id: String
    let label: String
    let sublabel: String

    static let defaults: [InputOption] = [
        InputOption(id: "y", label: "Y", sublabel: "Allow once"),
        InputOption(id: "a", label: "A", sublabel: "Allow all"),
        InputOption(id: "n", label: "N", sublabel: "Deny")
    ]

    static let yesNo: [InputOption] = [
        InputOption(id: "y", label: "Y", sublabel: "Yes"),
        InputOption(id: "n", label: "N", sublabel: "No")
    ]
}
