import Foundation

/// Mirrors the JSON shape returned by AuthController::userPayload() on the Laravel side
/// (app/Http/Controllers/Api/AuthController.php in the travianz-laravel repo) — keep the two in
/// sync if you add fields there.
struct GameUser: Codable, Equatable {
    let id: Int
    let name: String
    let email: String
    let tribe: String?
    let locale: String?
    let gold: Int
    let silver: Int
    let arenaPoints: Int
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, email, tribe, locale, gold, silver
        case arenaPoints = "arena_points"
        case isAdmin = "is_admin"
    }
}
