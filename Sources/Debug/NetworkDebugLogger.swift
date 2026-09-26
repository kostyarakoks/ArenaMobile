#if DEBUG
import Foundation

/// One logged request/response pair. Created when a request starts (so it shows up in the
/// overlay immediately, even while still in flight) and filled in once it finishes.
struct NetworkLogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let method: String
    let url: String
    let requestHeaders: [String: String]
    let requestBody: String?

    var statusCode: Int?
    var responseHeaders: [String: String]?
    var responseBody: String?
    var duration: TimeInterval?
    var errorDescription: String?

    var isPending: Bool { statusCode == nil && errorDescription == nil }
    var isSuccess: Bool { (200...299).contains(statusCode ?? 0) }
}

/// Central in-memory log of every request APIClient makes, feeding the NetworkDebugOverlay.
/// DEBUG-only end to end (see the #if wrapping this whole file, APIClient's hook, and
/// ArenaMobileApp's attach call) — none of this compiles into a release/App Store build, so
/// there's no risk of shipping request/response bodies (including auth tokens) to players.
@MainActor
final class NetworkDebugLogger: ObservableObject {
    static let shared = NetworkDebugLogger()

    @Published private(set) var entries: [NetworkLogEntry] = []

    private let maxEntries = 200

    private init() {}

    @discardableResult
    func begin(request: URLRequest) -> UUID {
        let entry = NetworkLogEntry(
            method: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "—",
            requestHeaders: Self.redacted(request.allHTTPHeaderFields ?? [:]),
            requestBody: Self.prettyBody(request.httpBody)
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        return entry.id
    }

    func complete(_ id: UUID, response: URLResponse?, data: Data?, started: Date) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let http = response as? HTTPURLResponse
        entries[index].statusCode = http?.statusCode
        if let http {
            let headers = http.allHeaderFields.reduce(into: [String: String]()) { acc, pair in
                acc["\(pair.key)"] = "\(pair.value)"
            }
            entries[index].responseHeaders = Self.redacted(headers)
        }
        entries[index].responseBody = Self.prettyBody(data)
        entries[index].duration = Date().timeIntervalSince(started)
    }

    func fail(_ id: UUID, error: Error, started: Date) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].errorDescription = error.localizedDescription
        entries[index].duration = Date().timeIntervalSince(started)
    }

    func clear() {
        entries.removeAll()
    }

    /// Masks the bearer token so a screenshot of the debug window doesn't leak a live session.
    private static func redacted(_ headers: [String: String]) -> [String: String] {
        var headers = headers
        if let auth = headers["Authorization"], auth.count > 14 {
            headers["Authorization"] = auth.prefix(14) + "…(hidden)"
        }
        return headers
    }

    private static func prettyBody(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: pretty, encoding: .utf8) {
            return string
        }
        return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes, not text>"
    }
}
#endif
