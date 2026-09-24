import Foundation
import SwiftUI

/// Фаза сессии — RootView по ней решает, показать Splash / Login / MainTab.
enum AuthPhase {
    case loading
    case signedOut
    case signedIn
}

/// Глобальное состояние авторизации. Основной путь — Game Center:
/// register(tribe:) получает teamPlayerID у GameCenterAuth, отправляет
/// на сервер, а сервер либо логинит в существующий аккаунт (по
/// game_center_player_id), либо создаёт нового игрока.
@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var bearerToken: String?
    @Published private(set) var currentUser: GameUser?
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    /// Используется RootView.
    @Published private(set) var phase: AuthPhase = .loading

    init() {
        bearerToken = KeychainHelper.readToken()
        phase = bearerToken == nil ? .signedOut : .loading
    }

    /// Регистрация/вход через Game Center. Игрок не вводит email/пароль —
    /// всё генерирует сервер. Если teamPlayerID уже привязан к аккаунту,
    /// сервер вернёт ЕГО токен, а не создаст новый (защита от повторной
    /// регистрации после переустановки приложения).
    ///
    /// `name` не передаём — сервер сам сгенерирует "Игрок id{ID}".
    func register(tribe: String) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let teamPlayerID = try await GameCenterAuth.shared.authenticate()

            let response = try await APIClient.shared.register(
                name: nil,
                tribe: tribe,
                deviceName: "ArenaMobile iOS",
                gameCenterPlayerID: teamPlayerID
            )

            bearerToken = response.token
            currentUser = response.user
            KeychainHelper.saveToken(response.token)
            phase = .signedIn
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось войти. Проверьте подключение к интернету."
        }
    }

    /// Логин существующего веб-аккаунта (запасной путь).
    func login(email: String, password: String) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await APIClient.shared.login(
                email: email,
                password: password,
                deviceName: "ArenaMobile iOS"
            )
            bearerToken = response.token
            currentUser = response.user
            KeychainHelper.saveToken(response.token)
            phase = .signedIn
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Неверный email или пароль."
        }
    }

    /// Восстановление сессии при старте приложения.
    func restoreSession() async {
        guard let token = bearerToken else {
            phase = .signedOut
            return
        }
        do {
            let user = try await APIClient.shared.fetchMe(token: token)
            currentUser = user
            phase = .signedIn
        } catch {
            signOutIfUnauthorized(error)
            if phase != .signedIn {
                phase = .signedOut
            }
        }
    }

    /// Перезагружает currentUser (золото, аллианс) — используется
    /// ShopView / AllianceView после действий, меняющих профиль.
    func refreshCurrentUser() async {
        guard let token = bearerToken else { return }
        do {
            currentUser = try await APIClient.shared.fetchMe(token: token)
        } catch {
            signOutIfUnauthorized(error)
        }
    }

    func logout() async {
        if let token = bearerToken {
            // APIClient.logout не throws — best-effort, поэтому без try?.
            await APIClient.shared.logout(token: token)
        }
        bearerToken = nil
        currentUser = nil
        KeychainHelper.deleteToken()
        phase = .signedOut
    }

    /// Если сервер вернул 401 — стираем локальный токен.
    func signOutIfUnauthorized(_ error: Error) {
        if let apiError = error as? APIError, case .unauthorized = apiError {
            bearerToken = nil
            currentUser = nil
            KeychainHelper.deleteToken()
            phase = .signedOut
        }
    }
}