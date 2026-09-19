import Foundation

/// Mirrors Api\CommanderController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// CommanderController.php, same CommanderService the web Commanders/Index.vue page uses.
struct CommanderCollection: Codable {
    let owned: [Commander]
    let squad: [String: Commander?]
    let roster: [RosterEntry]
    let recruitCost: Int
    let maxSquadSize: Int
    let bonuses: Bonuses

    struct Bonuses: Codable {
        let attack: Double
        let defense: Double
        let production: Double
    }
}

/// CommanderService::present() — its own array shape, untouched snake_case.
struct Commander: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let label: String
    let icon: String
    let portrait: String?
    let rarity: String
    let commanderClass: String
    let level: Int
    let maxLevel: Int
    let fragments: Int
    let fragmentsNeeded: Int
    let slot: Int?
    let power: Int

    enum CodingKeys: String, CodingKey {
        case id, key, label, icon, portrait, rarity, level, fragments, slot, power
        case commanderClass = "class"
        case maxLevel = "max_level"
        case fragmentsNeeded = "fragments_needed"
    }
}

/// CommanderController's own camelCased catalog output (not yet-owned templates).
struct RosterEntry: Codable, Identifiable {
    let key: String
    let label: String
    let icon: String
    let rarity: String
    let commanderClass: String
    let bonusAttackPct: Double
    let bonusDefensePct: Double
    let bonusProductionPct: Double

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, label, icon, rarity
        case commanderClass = "class"
        case bonusAttackPct, bonusDefensePct, bonusProductionPct
    }
}
