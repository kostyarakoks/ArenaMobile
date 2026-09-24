import Foundation
import SwiftUI

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var bearerToken: String?
    @Published private(set) var currentUser: GameUser?
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    init() {
        bearerToken = KeychainHelper.readToken()
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
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Неверный email или пароль."
        }
    }

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
        KeychainHelper.deleteToken()
    }

    func signOutIfUnauthorized(_ error: Error) {
        if let apiError = error as? APIError, case .unauthorized = apiError {
            bearerToken = nil
            currentUser = nil
            KeychainHelper.deleteToken()
        }
    }
}