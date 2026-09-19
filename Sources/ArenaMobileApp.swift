import SwiftUI

/// Entry point. SwiftUI's App protocol replaces the old AppDelegate/SceneDelegate dance —
/// this is the whole "app lifecycle" file for a modern SwiftUI-only project.
@main
struct ArenaMobileApp: App {
    @StateObject private var session = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .task {
                    // Runs once per launch: checks whether a token saved from a previous
                    // session (Keychain, see AuthSession.swift) is still valid before deciding
                    // between LoginView and MainTabView.
                    await session.restoreSession()
                }
        }
    }
}
