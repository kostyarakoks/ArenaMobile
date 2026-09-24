import Foundation
import GameKit
import os.log

/// Статус подключения к Game Center — используется LoginView для
/// показа бейджа и блокировки кнопки «Играть», пока подключения нет.
enum GameCenterStatus: Equatable {
    case unknown          // ещё не пробовали
    case connecting       // идёт аутентификация
    case connected(playerID: String, displayName: String)
    case failed(String)   // текст ошибки

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Обёртка над GKLocalPlayer. Аутентифицирует игрока и публикует
/// teamPlayerID. Именно teamPlayerID (не displayName!) отправляется
/// на сервер как ключ для поиска/создания аккаунта.
@MainActor
final class GameCenterAuth: ObservableObject {
    static let shared = GameCenterAuth()

    @Published private(set) var status: GameCenterStatus = .unknown

    private(set) var playerID: String?
    private(set) var displayName: String?

    private let log = Logger(subsystem: "com.arenaofthelords.mobile", category: "GameCenter")
    private var isAuthenticating = false

    /// Аутентификация с публикацией статуса в `status`. Повторные
    /// вызовы при уже подключённом GC возвращают кэш мгновенно.
    @discardableResult
    func authenticate() async throws -> String {
        if let playerID, case .connected = status {
            log.info("Game Center: cached teamPlayerID=\(playerID, privacy: .public)")
            return playerID
        }

        guard !isAuthenticating else {
            throw GameCenterError.authenticationInProgress
        }
        isAuthenticating = true
        status = .connecting
        defer { isAuthenticating = false }

        log.info("Game Center: starting authenticate()")

        do {
            let id = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                var didResume = false

                GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                    guard let self, !didResume else { return }

                    self.log.info("GC handler: isAuthenticated=\(GKLocalPlayer.local.isAuthenticated, privacy: .public), hasVC=\(viewController != nil, privacy: .public), error=\(String(describing: error), privacy: .public)")

                    if let error {
                        didResume = true
                        continuation.resume(throwing: error)
                        return
                    }

                    if viewController != nil {
                        // На современных iOS Apple показывает свой шит сама.
                        // Если сюда попали — значит, нужен ручной вход в настройки.
                        didResume = true
                        continuation.resume(throwing: GameCenterError.requiresUserInteraction)
                        return
                    }

                    if GKLocalPlayer.local.isAuthenticated {
                        let id = GKLocalPlayer.local.teamPlayerID
                        let name = GKLocalPlayer.local.displayName

                        guard !id.isEmpty else {
                            didResume = true
                            continuation.resume(throwing: GameCenterError.emptyTeamPlayerID)
                            return
                        }

                        self.playerID = id
                        self.displayName = name
                        didResume = true
                        continuation.resume(returning: id)
                    } else {
                        didResume = true
                        continuation.resume(throwing: GameCenterError.notAuthenticated)
                    }
                }
            }

            status = .connected(playerID: id, displayName: displayName ?? "Игрок")
            log.info("Game Center OK. teamPlayerID=\(id, privacy: .public), name=\(self.displayName ?? "?", privacy: .public)")
            return id
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            status = .failed(message)
            log.error("Game Center FAILED: \(message, privacy: .public)")
            throw error
        }
    }
}

enum GameCenterError: LocalizedError {
    case notAuthenticated
    case requiresUserInteraction
    case authenticationInProgress
    case emptyTeamPlayerID

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Войдите в Game Center в настройках iOS, чтобы играть."
        case .requiresUserInteraction:
            return "Требуется вход в Game Center. Откройте Настройки → Game Center и войдите."
        case .authenticationInProgress:
            return "Идёт вход в Game Center, подождите…"
        case .emptyTeamPlayerID:
            return "Game Center вернул пустой teamPlayerID. Проверьте, включён ли Game Center в настройках устройства."
        }
    }
}