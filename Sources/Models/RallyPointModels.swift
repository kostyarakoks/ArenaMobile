import Foundation

/// Mirrors Api\RallyPointController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// RallyPointController.php, same MovementService/ExpeditionService the web Village/RallyPoint.
/// vue page uses (expedition dispatch itself isn't ported — see that controller's docblock).
struct RallyPointDetail: Codable {
    let village: VillageInfo
    let troops: [StationedTroop]
    let outgoing: [Movement]
    let incoming: [Movement]
    let underConstruction: Bool
    let myOtherVillages: [TargetVillage]
    let allianceVillages: [AllianceTargetVillage]
    let worldHalf: Int

    struct VillageInfo: Codable {
        let id: Int
        let name: String
        let x: Int
        let y: Int
    }

    struct StationedTroop: Codable, Identifiable {
        let unitKey: String
        let label: String
        let count: Int
        var id: String { unitKey }
    }

    struct Movement: Codable, Identifiable {
        let id: Int
        let type: String
        let isReturn: Bool
        let targetX: Int
        let targetY: Int
        let arrivesAt: String
    }

    struct TargetVillage: Codable, Identifiable {
        let id: Int
        let name: String
        let x: Int
        let y: Int
        let isCapital: Bool
    }

    struct AllianceTargetVillage: Codable, Identifiable {
        let id: Int
        let name: String
        let x: Int
        let y: Int
        let owner: String
    }
}

/// Mirrors Api\TroopController::index()'s JSON — training queue for one of the 4 training
/// buildings (barracks/stable/workshop/residence).
struct TrainingDetail: Codable {
    let building: String
    let buildingLevel: Int
    let underConstruction: Bool
    let units: [TrainableUnit]
    let settlersUnlocked: Bool
    let queue: [QueueItem]

    struct TrainableUnit: Codable, Identifiable {
        let key: String
        let label: String
        let cost: [String: Int]
        let time: Int
        let attack: Int
        let defInf: Int
        let defCav: Int
        let maxAffordable: Int
        let locked: Bool
        var id: String { key }
    }

    struct QueueItem: Codable, Identifiable {
        let id: Int
        let label: String
        let count: Int
        let trained: Int
        let remaining: Int
        let nextCompletionAt: String
    }
}
