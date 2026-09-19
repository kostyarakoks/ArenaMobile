import Foundation

/// Mirrors Api\ArenaController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// ArenaController.php, same ArenaService the web Arena/Index.vue page uses.
struct ArenaDetail: Codable {
    let squad: [String: Commander?]
    let myPower: Int
    let arenaPoints: Int
    let opponent: Opponent

    struct Opponent: Codable {
        let userId: Int?
        let label: String
        let power: Int

        enum CodingKeys: String, CodingKey {
            case label, power
            case userId = "user_id"
        }
    }
}

/// Mirrors Api\ArenaController::fight()'s JSON.
struct ArenaFightResult: Codable {
    let won: Bool
    let opponentLabel: String
    let myPower: Int
    let opponentPower: Int
    let pointsDelta: Int
    let arenaPoints: Int
}
