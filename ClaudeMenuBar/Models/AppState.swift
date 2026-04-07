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
        InputOption(id: "y", label: "Y", sublabel: "允许一次"),
        InputOption(id: "a", label: "A", sublabel: "全部允许"),
        InputOption(id: "n", label: "N", sublabel: "拒绝")
    ]
}
