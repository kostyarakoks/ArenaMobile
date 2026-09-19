import Foundation

/// Mirrors Api\VillageController::index()'s JSON on the Laravel side — one entry per village
/// the player owns, for the village switcher.
struct VillageSummary: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let x: Int
    let y: Int
    let isCapital: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, x, y
        case isCapital = "is_capital"
    }
}

/// Mirrors Api\VillageController::show()'s JSON — everything VillageMapView needs to draw one
/// village's building-plot map the way Buildings.vue does: plot art, live build queue (for the
/// construction-progress overlay), and the village's tier label ("Поселение"/"Деревня"/
/// "Город"/"Мегаполис" — see App\Services\VillageTierService).
struct VillageDetail: Codable {
    let village: VillageInfo
    let buildings: [BuildingSlot]
    let queue: [QueueEntry]
    let queueFull: Bool
    let tribe: String?
    let wallLevel: Int
    let map: MapInfo

    struct VillageInfo: Codable {
        let id: Int
        let name: String
        let x: Int
        let y: Int
        let isCapital: Bool
        let wood: Int
        let clay: Int
        let iron: Int
        let crop: Int
        let population: Int
        let tierLabel: String?

        enum CodingKeys: String, CodingKey {
            case id, name, x, y, wood, clay, iron, crop, population, tierLabel
            case isCapital = "is_capital"
        }
    }

    struct BuildingSlot: Codable, Identifiable {
        let slot: Int
        let buildingKey: String?
        let level: Int
        // Nil for an empty plot — VillageBuilding::label() on the server returns null when
        // building_key is null, same as the web app's Buildings.vue gets. A non-optional String
        // here made JSONDecoder throw on any village with an unbuilt slot (i.e. almost every
        // village), which surfaced as "Сервер ответил в неожиданном формате" in the app.
        let label: String?
        let gid: Int?
        let hp: Int

        var id: Int { slot }

        enum CodingKeys: String, CodingKey {
            case slot, level, label, gid, hp
            case buildingKey = "buildingKey"
        }
    }

    /// One in-progress build-queue item — same shape VillageController::queueProps() sends the
    /// web app, so Buildings.vue's ConstructionProgress.vue and this app's matching overlay
    /// (see VillageMapView.ConstructionBadge) tick from the exact same started_at/finishes_at
    /// window. startedAt/finishesAt stay raw ISO-8601 strings (matches ResearchModels'
    /// convention) — parsed to Date at the point of use via ISO8601DateFormatter.
    struct QueueEntry: Codable, Identifiable {
        let slot: Int
        let queueType: String
        let label: String
        let toLevel: Int
        let startedAt: String
        let finishesAt: String
        let instantFinishCost: Int

        // A village's queue can hold more than one entry for the very same slot (an upgrade
        // queued to start right after the one ahead of it finishes) — slot alone isn't unique.
        var id: String { "\(slot)-\(toLevel)-\(startedAt)" }

        enum CodingKeys: String, CodingKey {
            case slot, label
            case queueType = "queue_type"
            case toLevel = "to_level"
            case startedAt = "started_at"
            case finishesAt = "finishes_at"
            case instantFinishCost = "instant_finish_cost"
        }
    }

    /// Present only when an admin has uploaded a real map template for this village — see
    /// App\Models\VillageMapTemplate. All three are nil together; VillageMapView then falls
    /// back to VillageLayout's hardcoded copy of the classic layout.
    struct MapInfo: Codable {
        let coords: [MapCoord]?
        let background: String?
        let viewboxWidth: Int?
        let viewboxHeight: Int?
    }

    struct MapCoord: Codable {
        let slot: Int
        let cx: Double
        let cy: Double
    }
}

/// Mirrors Api\VillageController::slot()'s JSON — App\Http\Controllers\VillageController's
/// slotPayload(), the same "what can I build/upgrade here" catalogue UpgradeModal.vue and
/// EmptyPlotOverlay.vue both render from. Decoding-only: the app never re-sends this shape, it
/// posts a plain building_key/instant pair instead (see APIClient.performSlotAction).
struct SlotDetail: Decodable {
    let slot: SlotInfo
    let catalogue: [BuildingCandidate]
    let queueFull: Bool

    struct SlotInfo: Decodable {
        let slot: Int
        let buildingKey: String?
        let level: Int
        let label: String?

        enum CodingKeys: String, CodingKey {
            case slot, level, label
            case buildingKey = "building_key"
        }
    }
}

struct BuildResourceCost: Decodable {
    let wood: Int
    let clay: Int
    let iron: Int
    let crop: Int
}

/// BuildingService::bonusStat()'s shape — e.g. {label: "Вместимость склада", value: 4800,
/// suffix: ""} or {label: "Защита", value: 12, suffix: "%"}.
struct BuildingBonusStat: Decodable {
    let label: String
    let value: Int
    let suffix: String
}

struct BuildingRequirement: Decodable, Identifiable {
    let key: String
    let label: String
    let level: Int
    let met: Bool
    let slot: Int?

    var id: String { key }
}

/// One catalogue entry — either the type already built on this slot (level > 0, upgradeable),
/// or one of the types that could be built here instead (level 0). Same fields
/// App\Http\Controllers\VillageController::slotPayload() sends the web app, mapped in
/// Buildings.vue's openModal()/EmptyPlotOverlay.vue into UpgradeModal's `item` prop — this
/// struct plays both roles at once instead of the web's separate catalogue-entry vs.
/// modal-item shapes.
struct BuildingCandidate: Decodable, Identifiable {
    let key: String
    let label: String
    let description: String?
    let effect: String?
    let gid: Int
    let maxLevel: Int
    let currentLevel: Int
    let canBuild: Bool
    let requirementsMet: Bool
    let alreadyBuiltElsewhere: Bool
    let nextCost: BuildResourceCost?
    let nextTime: Int?
    let instantFinishCost: Int?
    let bonusCurrent: BuildingBonusStat?
    let bonusNext: BuildingBonusStat?
    let requires: [BuildingRequirement]

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, label, description, effect, gid, requires
        case maxLevel = "max_level"
        case currentLevel = "current_level"
        case canBuild = "can_build"
        case requirementsMet = "requirements_met"
        case alreadyBuiltElsewhere = "already_built_elsewhere"
        case nextCost = "next_cost"
        case nextTime = "next_time"
        case instantFinishCost = "instant_finish_cost"
        case bonusCurrent = "bonus_current"
        case bonusNext = "bonus_next"
    }
}
