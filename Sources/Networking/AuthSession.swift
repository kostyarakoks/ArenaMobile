import Foundation

/// App-wide auth state — owns the Sanctum bearer token and the logged-in user, and decides
/// whether RootView shows the splash screen, LoginView, or MainTabView (see RootView.swift).
/// One instance lives for the app's lifetime, injected as an @EnvironmentObject from
/// ArenaMobileApp.swift.
@MainActor
final class AuthSession: ObservableObject {
    enum Phase {
        case checkingStoredToken // splash screen while we validate a token left over from last launch
        case signedOut
        case signedIn
    }

    @Published private(set) var phase: Phase = .checkingStoredToken
    @Published private(set) var currentUser: GameUser?
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    private static let tokenKeychainKey = "auth.token"

    private var token: String? {
        didSet {
            if let token {
                KeychainHelper.save(token, forKey: Self.tokenKeychainKey)
            } else {
                KeychainHelper.delete(forKey: Self.tokenKeychainKey)
            }
        }
    }

    /// Read-only outward view of the token, for views/services that need to make their own
    /// authenticated requests (e.g. VillageMapView loading /api/villages) without AuthSession
    /// having to grow a method for every single endpoint in the app.
    var bearerToken: String? { token }

    /// Call once, right after launch (see ArenaMobileApp.swift) — if a token was saved from a
    /// previous session, confirms it's still valid (the player might have been logged out
    /// server-side, or the token could have been revoked) before dropping straight into
    /// MainTabView instead of making them log in again every time they open the app.
    func restoreSession() async {
        guard let savedToken = KeychainHelper.read(forKey: Self.tokenKeychainKey) else {
            phase = .signedOut
            return
        }
        do {
            let user = try await APIClient.shared.fetchMe(token: savedToken)
            token = savedToken
            currentUser = user
            phase = .signedIn
        } catch {
            // Stored token is stale/invalid/server unreachable — fall back to the login screen
            // rather than getting stuck on the splash screen forever.
            token = nil
            currentUser = nil
            phase = .signedOut
        }
    }

    func login(email: String, password: String) async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let deviceName = "ArenaMobile iOS (\(UIDeviceNameProvider.name))"
            let (token, user) = try await APIClient.shared.login(email: email, password: password, deviceName: deviceName)
            self.token = token
            self.currentUser = user
            self.phase = .signedIn
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось войти."
        }
    }

    /// "Instant play" — tap a nickname + tribe in, no email/password ever entered (see
    /// Api\AuthController::register). This is the primary way a NEW player gets into the game
    /// now (WelcomeView's "Играть"); login(email:password:) above stays only for someone who
    /// already has an account from the web app and wants to attach this device to it.
    func register(name: String, tribe: String) async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let deviceName = "ArenaMobile iOS (\(UIDeviceNameProvider.name))"
            // Best-effort — see GameCenterAuth's own doc comment for why a nil result here still
            // lets registration through rather than blocking it.
            let gameCenterPlayerID = await GameCenterAuth.shared.authenticate()
            let (token, user) = try await APIClient.shared.register(name: name, tribe: tribe, deviceName: deviceName, gameCenterPlayerID: gameCenterPlayerID)
            self.token = token
            self.currentUser = user
            self.phase = .signedIn
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось создать аккаунт."
        }
    }

    /// Re-fetches /api/me and updates currentUser in place — called after any action that
    /// changes something GameUser carries (e.g. joining/leaving an alliance changes
    /// allianceId) so the rest of the app sees the new value without a full re-login.
    func refreshCurrentUser() async {
        guard let token else { return }
        if let user = try? await APIClient.shared.fetchMe(token: token) {
            currentUser = user
        }
    }

    /// Any authenticated screen (e.g. VillageMapView) can call this from its catch block —
    /// if the token got revoked server-side (password change, admin action, expired) mid-
    /// session, this drops the app back to LoginView instead of leaving it stuck showing a
    /// generic network-error state forever.
    func signOutIfUnauthorized(_ error: Error) {
        if case APIError.unauthorized = error {
            logout()
        }
    }

    func logout() {
        let tokenToRevoke = token
        token = nil
        currentUser = nil
        phase = .signedOut
        if let tokenToRevoke {
            Task { await APIClient.shared.logout(token: tokenToRevoke) }
        }
    }
}

#if canImport(UIKit)
import UIKit
enum UIDeviceNameProvider {
    static var name: String { UIDevice.current.name }
}
#else
enum UIDeviceNameProvider {
    static var name: String { "unknown device" }
}
#endif
