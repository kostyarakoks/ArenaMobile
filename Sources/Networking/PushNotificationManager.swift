import UIKit
import UserNotifications

/// Real APNs push ("добавить пуш" — the user explicitly asked for real server push, not just
/// local notifications). Owns the "ask for permission -> register with Apple -> tell our own
/// server the resulting device token" pipeline; the actual sending happens server-side (see
/// travianz-laravel's PushNotificationService, wired into BuildingService::completeQueueItem()
/// for "Строительство завершено" pushes).
///
/// A singleton (mirrors GameCenterAuth.shared's own pattern) rather than an @EnvironmentObject:
/// AppDelegate (a plain UIApplicationDelegate, not part of the SwiftUI view tree) needs to reach
/// it directly from didRegisterForRemoteNotificationsWithDeviceToken, which an environment
/// object can't provide.
///
/// IMPORTANT — this can only ever reach Apple's real APNs servers on a build signed with a
/// provisioning profile that has the Push Notifications capability + aps-environment
/// entitlement (see ArenaMobile.entitlements's own comment). The GitHub Actions CI build is
/// unsigned (CODE_SIGNING_ALLOWED: "NO" in project.yml) specifically so it can produce an .ipa
/// without a paid Apple Developer account at all — requestAuthorization()/
/// registerForRemoteNotifications() will still run on that build, but Apple will refuse to hand
/// back a real device token (or the OS may not even prompt), so nothing downstream of this can
/// actually receive a push until the app is properly signed with that capability enabled.
@MainActor
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    /// Set once by AuthSession at init — lets this manager read whichever bearer token is
    /// CURRENTLY signed in whenever it needs to register a device token with the server,
    /// without AuthSession having to observe this class's own state back. Mirrors the existing
    /// direction of GameCenterAuth (AuthSession calls INTO it), just inverted because this one
    /// needs to react to an AppDelegate callback AuthSession has no visibility into.
    var bearerTokenProvider: (() -> String?)?

    // Not `private` — AuthSession.logout() reads this to unregister the device token from the
    // account that's signing out (see AuthSession.swift's own doc comment on that call).
    private(set) var pendingDeviceTokenHex: String?

    private override init() { super.init() }

    /// Call once the player is actually signed in (see AuthSession.login/register/
    /// restoreSession) — asking before that would show the permission prompt on the splash/
    /// login screen, before there's even an account to attach the resulting token to.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Called from AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken.
    func handleDeviceToken(_ data: Data) {
        pendingDeviceTokenHex = data.map { String(format: "%02x", $0) }.joined()
        registerWithServerIfPossible()
    }

    /// Also called right after sign-in completes (AuthSession) in case Apple already handed
    /// back a device token from an EARLIER launch/session before this one signed back in —
    /// permission + registration and login/register happen independently, in no guaranteed
    /// order, so either side arriving needs to try completing the pairing.
    func registerWithServerIfPossible() {
        guard let hex = pendingDeviceTokenHex, let bearerToken = bearerTokenProvider?() else { return }
        Task {
            try? await APIClient.shared.registerDeviceToken(hex, token: bearerToken)
        }
    }
}
