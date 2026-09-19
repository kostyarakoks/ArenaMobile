import Foundation

/// Mirrors Api\StatisticsController::index()'s JSON — travianz-laravel/app/Http/Controllers/
/// Api/StatisticsController.php, same 4 rankings the web Statistics/Index.vue page shows.
struct StatisticsResponse: Codable {
    let leaderboard: Leaderboard

    struct Leaderboard: Codable {
        let byPopulation: [LeaderboardRow]
        let byProduction: [LeaderboardRow]
        let byOffense: [LeaderboardRow]
        let byDefense: [LeaderboardRow]
    }
}

struct LeaderboardRow: Codable, Identifiable {
    let userId: Int
    let name: String
    let tribe: String?
    let villagesCount: Int
    let population: Int
    let production: Int
    let offense: Int
    let defense: Int

    var id: Int { userId }
}

enum LeaderboardMetric: String, CaseIterable, Identifiable {
    case population, production, offense, defense
    var id: String { rawValue }
    var label: String {
        switch self {
        case .population: return "Население"
        case .production: return "Добыча"
        case .offense: return "Атака"
        case .defense: return "Оборона"
        }
    }
    func rows(in leaderboard: StatisticsResponse.Leaderboard) -> [LeaderboardRow] {
        switch self {
        case .population: return leaderboard.byPopulation
        case .production: return leaderboard.byProduction
        case .offense: return leaderboard.byOffense
        case .defense: return leaderboard.byDefense
        }
    }
    func value(_ row: LeaderboardRow) -> Int {
        switch self {
        case .population: return row.population
        case .production: return row.production
        case .offense: return row.offense
        case .defense: return row.defense
        }
    }
}
