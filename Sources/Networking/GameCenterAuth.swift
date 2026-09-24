import Foundation
import GameKit

/// Обёртка над GKLocalPlayer. Задача — один раз аутентифицировать игрока
/// в Game Center и закэшировать его teamPlayerID (стабильный идентификатор
/// Apple ID, не меняется между запусками и переустановками приложения).
///
/// Именно teamPlayerID (а не displayName!) отправляется на сервер как
/// единственный надёжный ключ для поиска существующего аккаунта. displayName
/// игрок может менять в настройках Game Center, и использовать его как
/// идентификатор нельзя.
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

        // Защита от параллельных вызовов (например, если пользователь
        // быстро тапает "Играть" несколько раз).
        guard !isAuthenticating else {
            throw GameCenterError.authenticationInProgress
        }
        isAuthenticating = true
        defer { isAuthenticating = false }

        return try await withCheckedThrowingContinuation { continuation in
            // authenticateHandler может вызываться несколько раз — но continuation
            // резюмируется ровно один раз (флаг didResume).
            var didResume = false

            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                guard let self, !didResume else { return }

                if let error {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }

                // Game Center иногда просит показать UI входа (старые версии iOS).
                // На современных системах Apple показывает свой шит сама, и сюда
                // мы не попадаем. Если попали — считаем это "требуется действие
                // пользователя" и просим его открыть настройки.
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