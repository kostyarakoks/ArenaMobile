import SwiftUI

/// Entry point. SwiftUI's App protocol replaces the old AppDelegate/SceneDelegate dance for
/// almost everything — the one exception is real push notifications ("добавить пуш"), which
/// need AppDelegate.swift's small UIApplicationDelegate bridge (see its own doc comment for why).
@main
struct ArenaMobileApp: App {
    // Wires AppDelegate's didRegisterForRemoteNotificationsWithDeviceToken/
    // didFailToRegisterForRemoteNotificationsWithError into this SwiftUI app's own lifecycle —
    // SwiftUI creates and owns the AppDelegate instance itself.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .networkDebugOverlay()
                .task {
                    // Runs once per launch: checks whether a token saved from a previous
                    // session (Keychain, see AuthSession.swift) is still valid before deciding
                    // between LoginView and MainTabView.
                    await session.restoreSession()
                }
        }
    }
}
