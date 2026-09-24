import Foundation
import SwiftUI

/// Глобальное состояние авторизации. Держит bearer-токен (Keychain),
/// текущего пользователя и методы login/register/logout. Game Center-логин
/// встроен в register(): клиент получает teamPlayerID у GameCenterAuth,
/// отправляет его на сервер, а сервер сам решает — создать новый аккаунт
/// или вернуть токен существующего (по game_center_player_id).
@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var bearerToken: String?
    @Published private(set) var currentUser: GameUser?
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let keychain = KeychainStore()

    init() {
        // Восстанавливаем сохранённый токен при старте, чтобы не гонять
        // игрока через Game Center каждый раз.
        bearerToken = keychain.readToken()
    }

    /// Регистрация/вход через Game Center. ЕДИНСТВЕННЫЙ основной путь для
    /// новых игроков. Поля email/password не спрашиваются — все креды
    /// генерирует сервер. Если у устройства уже есть аккаунт (по teamPlayerID),
    /// сервер вернёт токен существующего аккаунта, а не создаст новый —
    /// это защищает от повторных регистраций.
    ///
    /// `name` НЕ передаём (nil) — сервер сам сгенерирует "Игрок id{ID}".
    func register(tribe: String) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            // 1. Аутентификация в Game Center (при первом запуске — диалог
            //    Apple, дальше — мгновенно из кэша GKLocalPlayer).
            let teamPlayerID = try await GameCenterAuth.shared.authenticate()

            // 2. Отправляем teamPlayerID + племя. Имя НЕ передаём — сервер
            //    сам сгенерирует "Игрок id{N}". Если игрок с таким teamPlayerID
            //    уже существует, сервер вернёт токен существующего аккаунта.
            let response = try await APIClient.shared.register(
                name: nil,
                tribe: tribe,
                deviceName: "ArenaMobile iOS",
                gameCenterPlayerID: teamPlayerID
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
            let response = try await APIClient.shared.login(
                email: email,
                password: password,
                deviceName: "ArenaMobile iOS"
            )
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
            let user = try await APIClient.shared.fetchMe(token: token)
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