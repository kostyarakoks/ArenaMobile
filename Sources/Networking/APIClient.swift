import Foundation

enum APIError: LocalizedError {
    case invalidServerURL
    case server(message: String)
    case decoding
    case unauthorized
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Некорректный адрес сервера. Проверьте URL в настройках."
        case .server(let message):
            return message
        case .decoding:
            return "Сервер ответил в неожиданном формате."
        case .unauthorized:
            return "Сессия истекла, войдите заново."
        case .transport(let error):
            return "Нет соединения с сервером: \(error.localizedDescription)"
        }
    }
}

/// Talks to the Laravel backend's bearer-token API (routes/api.php + AuthController — see the
/// travianz-laravel repo). Only login/me/logout exist server-side so far; add more methods here
/// as routes/api.php grows past just auth.
final class APIClient {
    static let shared = APIClient()

    /// Persisted so the app can point at a different server (staging, a friend's install, ...)
    /// without a rebuild. Set this on the login screen before signing in — see LoginView.swift.
    /// There is no sensible built-in default (every TravianZ install lives at its own domain),
    /// so this starts empty and LoginView refuses to submit until it looks like a URL.
    static let baseURLDefaultsKey = "api.baseURL"

    var baseURL: URL? {
        guard let raw = UserDefaults.standard.string(forKey: Self.baseURLDefaultsKey),
              !raw.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: raw) else { return nil }
        return url
    }

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = .init()

    private struct LoginResponse: Codable {
        let token: String
        let user: GameUser
    }

    private struct MeResponse: Codable {
        let user: GameUser
    }

    private struct ErrorResponse: Codable {
        let message: String?
    }

    func login(email: String, password: String, deviceName: String) async throws -> (token: String, user: GameUser) {
        var request = try makeRequest(path: "/api/login", method: "POST")
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "password": password,
            "device_name": deviceName,
        ])

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(LoginResponse.self, from: data) else {
            throw APIError.decoding
        }
        return (decoded.token, decoded.user)
    }

    func fetchMe(token: String) async throws -> GameUser {
        var request = try makeRequest(path: "/api/me", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(MeResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded.user
    }

    private struct VillagesResponse: Codable {
        let villages: [VillageSummary]
    }

    func fetchVillages(token: String) async throws -> [VillageSummary] {
        var request = try makeRequest(path: "/api/villages", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(VillagesResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded.villages
    }

    func fetchVillage(id: Int, token: String) async throws -> VillageDetail {
        var request = try makeRequest(path: "/api/villages/\(id)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(VillageDetail.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    func fetchWorldMap(centerX: Int, centerY: Int, token: String) async throws -> WorldMapResponse {
        var request = try makeRequest(path: "/api/map?x=\(centerX)&y=\(centerY)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(WorldMapResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    func fetchPublicVillage(id: Int, token: String) async throws -> PublicVillage {
        var request = try makeRequest(path: "/api/map/villages/\(id)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(PublicVillage.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    func logout(token: String) async {
        guard var request = try? makeRequest(path: "/api/logout", method: "POST") else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Best-effort: if this fails (offline, server already forgot the token, ...) we still
        // drop the local token in AuthSession.logout() right after calling this.
        _ = try? await perform(request)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let base = baseURL else { throw APIError.invalidServerURL }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
    }

    private static func checkStatus(_ response: URLResponse, data: Data, decoder: JSONDecoder) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        default:
            if let decoded = try? decoder.decode(ErrorResponse.self, from: data), let message = decoded.message {
                throw APIError.server(message: message)
            }
            throw APIError.server(message: "Сервер вернул ошибку (\(http.statusCode)).")
        }
    }
}
