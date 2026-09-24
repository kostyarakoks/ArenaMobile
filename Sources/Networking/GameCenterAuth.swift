import Foundation
import GameKit

/// Обёртка над GKLocalPlayer. Аутентифицирует игрока в Game Center и
/// возвращает teamPlayerID — стабильный идентификатор Apple ID, который
/// не меняется между запусками и переустановками приложения. Именно он
/// отправляется на сервер как ключ для поиска/создания аккаунта
/// (см. AuthSession.register).
@MainActor
final class GameCenterAuth {
    static let shared = GameCenterAuth()

    private(set) var playerID: String?
    private(set) var displayName: String?

    private var isAuthenticating = false

    /// Аутентифицирует игрока в Game Center и возвращает teamPlayerID.
    /// Повторные вызовы возвращают закэшированный ID без диалогов.
    func authenticate() async throws -> String {
        if let playerID {
            return playerID
        }

        guard !isAuthenticating else {
            throw GameCenterError.authenticationInProgress
        }
        isAuthenticating = true
        defer { isAuthenticating = false }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                guard let self, !didResume else { return }

                if let error {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }

                if viewController != nil {
                    didResume = true
                    continuation.resume(throwing: GameCenterError.requiresUserInteraction)
                    return
                }

                if GKLocalPlayer.local.isAuthenticated {
                    let id = GKLocalPlayer.local.teamPlayerID
                    self.playerID = id
                    self.displayName = GKLocalPlayer.local.displayName
                    didResume = true
                    continuation.resume(returning: id)
                } else {
                    didResume = true
                    continuation.resume(throwing: GameCenterError.notAuthenticated)
                }
            }
        }
    }
}

enum GameCenterError: LocalizedError {
    case notAuthenticated
    case requiresUserInteraction
    case authenticationInProgress

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Войдите в Game Center в настройках iOS, чтобы играть."
        case .requiresUserInteraction:
            return "Требуется вход в Game Center. Откройте Настройки → Game Center и войдите."
        case .authenticationInProgress:
            return "Идёт вход в Game Center, подождите…"
        }
    }
}