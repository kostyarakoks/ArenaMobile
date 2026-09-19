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
