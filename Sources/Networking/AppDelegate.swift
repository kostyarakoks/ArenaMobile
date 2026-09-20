import UIKit

/// SwiftUI's App protocol normally replaces the old AppDelegate/SceneDelegate dance entirely
/// (see ArenaMobileApp.swift's own doc comment) — but
/// application(_:didRegisterForRemoteNotificationsWithDeviceToken:) only exists on
/// UIApplicationDelegate, with no SwiftUI-native equivalent, so real push notifications
/// ("добавить пуш") need this one small bridge back to UIKit's app-lifecycle callbacks via
/// @UIApplicationDelegateAdaptor (see ArenaMobileApp.swift).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushNotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on the unsigned CI/Sideloadly build path (see PushNotificationManager's own
        // doc comment) — not surfaced to the player, since local build/dev builds shouldn't
        // show an error for a capability that's simply not signed in yet.
        #if DEBUG
        print("APNs registration failed: \(error)")
        #endif
    }
}
