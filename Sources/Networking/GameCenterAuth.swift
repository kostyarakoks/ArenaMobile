import GameKit
import UIKit

/// Authenticates the device's local Game Center player and hands back Apple's stable
/// `teamPlayerID` — an identifier tied to the player's Apple ID / Game Center account, NOT to
/// this one app install. Sent along with register() (see APIClient.RegisterBody) so
/// Api\AuthController::register() can recognize "this Game Center player already has an
/// account" and sign back into it instead of minting a brand-new one, per: "подключить гейм
/// центер что бы после выхода из игры нельзя было регистровать новый аккаунт" — reinstalling
/// (or logging out and hitting "Играть" again) no longer gets you a second, fresh account, since
/// the identifier survives a reinstall the way a locally-stored token or UUID never could.
///
/// `teamPlayerID` (not `gamePlayerID`) is used deliberately: `gamePlayerID` is scoped per
/// Apple-Developer-Team, so it would change if this app ever moved to a different team/bundle
/// signing setup; `teamPlayerID` stays the same for that player across every game from the same
/// developer, which is the more durable "who is this person" key for an anti-multi-account check.
@MainActor
final class GameCenterAuth {
    static let shared = GameCenterAuth()

    private(set) var isAuthenticated = false
    private var continuation: CheckedContinuation<String?, Never>?

    private init() {}

    /// Call once, early (see ArenaMobileApp.swift / WelcomeView, before register()/login() run) —
    /// presents Apple's own Game Center sign-in sheet if needed and resolves to the local
    /// player's `teamPlayerID`. Resolves to `nil` — never throws — when the player isn't signed
    /// into Game Center at all, declines the sheet, or Game Center is restricted (parental
    /// controls, some region/MDM configurations): callers treat `nil` as "no anti-multi-account
    /// check available on this device", not as a reason to block play, since plenty of real
    /// players keep Game Center switched off entirely.
    func authenticate() async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            self.continuation = continuation
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                guard let self else { return }
                Task { @MainActor in
                    if let viewController {
                        self.present(viewController)
                        // Don't resume yet — authenticateHandler fires again once the player
                        // finishes (or dismisses) this sheet, that time with viewController nil.
                        return
                    }
                    let player = GKLocalPlayer.local
                    self.isAuthenticated = player.isAuthenticated
                    self.resume(with: player.isAuthenticated ? player.teamPlayerID : nil)
                }
            }
        }
    }

    private func resume(with playerID: String?) {
        continuation?.resume(returning: playerID)
        continuation = nil
    }

    private func present(_ viewController: UIViewController) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = (scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first)?.rootViewController
        else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(viewController, animated: true)
    }
}
