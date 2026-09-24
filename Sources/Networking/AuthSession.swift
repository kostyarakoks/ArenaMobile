import Foundation
import SwiftUI

/// Глобальное состояние авторизации. Держит bearer-токен (Keychain), текущего
/// пользователя и методы login/register/logout. Game Center-логин теперь
/// встроен в `register`: клиент сначала получает teamPlayerID у GameCenterAuth,
/// затем отправляет его на сервер, а сервер сам решает — создать новый аккаунт
/// или вернуть токен существующего.
@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var bearerToken: String?
    @Published private(set) var currentUser: GameUser?
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let keychain = KeychainStore()

    init() {
        // При старте приложения пробуем восстановить сохранённый токен,
        // чтобы не гонять игрока через Game Center каждый раз.
        bearerToken = keychain.readToken()
    }

    /// Регистрация/вход через Game Center. Единственный "передний" путь для
    /// новых игроков — поля email/password не спрашиваются, все креды
    /// генерирует сервер. Если игрок с таким teamPlayerID уже существует,
    /// сервер вернёт токен существующего аккаунта — повторной регистрации
    /// не произойдёт.
    func register(tribe: String) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            // 1. Аутентификация в Game Center (при первом запуске — диалог
            //    Apple, дальше — мгновенно из кэша).
            let teamPlayerID = try await GameCenterAuth.shared.authenticate()

            // 2. Отправляем его на сервер. Имя НЕ передаём — сервер сам
            //    сгенерирует "Игрок id{N}" для нового аккаунта.
            let response = try await APIClient.shared.registerWithGameCenter(
                gameCenterPlayerID: teamPlayerID,
                tribe: tribe
            )

            // 3. Сохраняем токен и пользователя.
            bearerToken = response.token
            currentUser = response.user
            keychain.saveToken(response.token)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось войти. Проверьте подключение к интернету."
        }
    }

    /// Логин для существующего веб-аккаунта (запасной путь, не основной).
    func login(email: String, password: String) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await APIClient.shared.login(email: email, password: password)
            bearerToken = response.token
            currentUser = response.user
            keychain.saveToken(response.token)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Неверный email или пароль."
        }
    }

    /// Проверка токена при запуске приложения. Если сервер вернул 401 —
    /// токен протух, разлогиниваем.
    func restoreSession() async {
        guard let token = bearerToken else { return }
        do {
            let user = try await APIClient.shared.fetchCurrentUser(token: token)
            currentUser = user
        } catch {
            signOutIfUnauthorized(error)
        }
    }

    func logout() async {
        if let token = bearerToken {
            try? await APIClient.shared.logout(token: token)
        }
        bearerToken = nil
        currentUser = nil
        keychain.deleteToken()
    }

    /// Если сервер вернул 401 — стираем локальный токен, чтобы RootView
    /// переключился обратно на LoginView.
    func signOutIfUnauthorized(_ error: Error) {
        if let apiError = error as? APIError, case .unauthorized = apiError {
            bearerToken = nil
            currentUser = nil
            keychain.deleteToken()
        }
    }
}