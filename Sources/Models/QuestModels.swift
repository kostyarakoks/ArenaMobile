import Foundation

/// Mirrors Api\QuestController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// QuestController.php, same QuestService the web Quests/Index.vue page uses. title/description
/// are resolved server-side by the API controller itself (see its docblock) since the mobile
/// app doesn't carry the full translations bundle the web app gets.
struct QuestStatus: Codable {
    let chain: [QuestItem]
    let chainDone: Bool
    let chainTotal: Int
    let chainCompleted: Int
    let tail: [QuestItem]
}

struct QuestItem: Codable, Identifiable {
    let key: String
    let index: Int
    let reward: [String: Int]
    let gold: Int
    let state: String
    let title: String
    let description: String
    let cooldownHours: Int?
    let readyAt: String?

    var id: String { key }
}
