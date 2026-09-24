import Foundation
import SwiftUI

enum AuthPhase {
    case loading
    case signedOut
    case signedIn
}

/// Глобальное состояние авторизации. Основной путь — Game Center.
/// Статус подключения GC живёт в GameCenterAuth.shared.status и
/// читается LoginView напрямую; здесь только логика регистрации/логина.
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