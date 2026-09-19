import Foundation

/// Mirrors Api\ResearchController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// ResearchController.php, same ResearchService the web Research/Index.vue page uses.
struct ResearchDetail: Codable {
    let tribe: String?
    let academyLevel: Int
    let chain: [ResearchEntry]
    let active: ActiveResearch?

    struct ActiveResearch: Codable {
        let key: String
        let label: String
        let startedAt: String
        let finishesAt: String
    }
}

struct ResearchEntry: Codable, Identifiable {
    let key: String
    let label: String
    let description: String?
    let cost: [String: Int]
    let time: Int
    let requiresAcademyLevel: Int
    let isResearched: Bool
    let isAvailable: Bool
    var id: String { key }
}

/// Mirrors Api\TechTreeController::index()'s JSON — a flat list grouped by tier (dependency
/// depth) rather than a rendered node graph like the web TechTree/Index.vue's canvas — same
/// information, simpler to browse on a phone screen.
struct TechTreeResponse: Codable {
    let nodes: [TechTreeNode]
    let tierCount: Int
    let hasVillage: Bool
}

struct TechTreeNode: Codable, Identifiable {
    let key: String
    let label: String
    let description: String?
    let tier: Int
    let currentLevel: Int
    let maxLevel: Int
    let isBuilt: Bool
    let isAvailable: Bool
    let requires: [Requirement]

    var id: String { key }

    struct Requirement: Codable {
        let key: String
        let label: String
        let level: Int
    }
}
