import SwiftUI

@main
struct ClaudeMenuBarApp: App {
    @StateObject private var controller = MenuBarController()

    var body: some Scene {
        Settings { EmptyView() }
    }
}
