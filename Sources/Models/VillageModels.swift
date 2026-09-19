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
/// village's building-plot map.
struct VillageDetail: Codable {
    let village: VillageInfo
    let buildings: [BuildingSlot]
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

        enum CodingKeys: String, CodingKey {
            case id, name, x, y, wood, clay, iron, crop, population
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
