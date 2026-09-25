import Foundation
import SwiftUI

/// Фаза сессии — RootView по ней решает, показать Splash / Login / MainTab.
enum AuthPhase {
    case loading
    case signedOut
    case signedIn
}

/// Глобальное состояние авторизации. Регистрация — instant-play:
/// клиент отправляет только племя, ник генерирует сервер ("Игрок id{ID}").
@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var bearerToken: String?
    @Published private(set) var currentUser: GameUser?
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    @Published private(set) var phase: AuthPhase = .loading

    init() {
        bearerToken = KeychainHelper.readToken()
        phase = bearerToken == nil ? .signedOut : .loading
    }

    /// Сбросить временное состояние UI. Вызывается из LoginView.onAppear,
    /// чтобы кнопка «Играть» не оставалась серой после залипшего запроса.
    func resetTransientState() {
        isSubmitting = false
        errorMessage = nil
    }

    /// Регистрация instant-play. Ник НЕ передаём — сервер сам сгенерирует
    /// "Игрок id{ID}", где {ID} = users.id. Клиент отправляет только племя.
    func register(tribe: String) async {
        guard !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await APIClient.shared.register(
                tribe: tribe,
                deviceName: "ArenaMobile iOS"
            )

            bearerToken = response.token
            currentUser = response.user
            KeychainHelper.saveToken(response.token)
            phase = .signedIn
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось зарегистрироваться. Проверьте подключение к интернету."
        }
    }

    func login(email: String, password: String) async {
        guard !isSubmitting else { return }

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

    /// Применить уже полученного с сервера пользователя (например, после смены аватара —
    /// APIClient.setAvatarPreset/uploadAvatar уже вернули свежий GameUser в ответе, так что
    /// отдельный GET /api/me не нужен). `currentUser` — private(set), поэтому экранам вроде
    /// ProfileScreen нужен этот сеттер, а не прямое присваивание.
    func applyUpdatedUser(_ user: GameUser) {
        currentUser = user
    }

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
            await APIClient.shared.logout(token: token)
        }
        bearerToken = nil
        currentUser = nil
        KeychainHelper.deleteToken()
        phase = .signedOut
    }

    func signOutIfUnauthorized(_ error: Error) {
        if let apiError = error as? APIError, case .unauthorized = apiError {
            bearerToken = nil
            currentUser = nil
            KeychainHelper.deleteToken()
            phase = .signedOut
        }
    }
}