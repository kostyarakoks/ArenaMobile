import SwiftUI

/// Entry point. SwiftUI's App protocol replaces the old AppDelegate/SceneDelegate dance —
/// this is the whole "app lifecycle" file for a modern SwiftUI-only project.
@main
struct ArenaMobileApp: App {
    @StateObject private var gameState = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameState)
        }
    }
}
