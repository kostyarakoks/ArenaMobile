import Foundation

/// Mirrors Api\MapController::index()'s JSON — a window of world-map tiles centred on some
/// (x,y), plus the player's own villages for the quick-jump list. `tiles` is a FLAT array,
/// already ordered top row (maxY) to bottom row (minY), left (minX) to right (maxX) within
/// each row — see App\Services\WorldMapService::tiles() — so WorldMapView chunks it back into
/// rows using `bounds` rather than needing an (x,y) lookup.
struct WorldMapResponse: Codable {
    let center: Coord
    let gridSize: Int
    let bounds: Bounds
    let worldSize: Int
    let visionRadius: Int
    let tiles: [WorldMapTile]
    let myVillages: [VillageSummary]

    struct Coord: Codable {
        let x: Int
        let y: Int
    }

    struct Bounds: Codable {
        let minX: Int
        let maxX: Int
        let minY: Int
        let maxY: Int
    }
}

/// One map cell. `foggy` tiles are outside the vision radius around all of the player's own
/// villages (see WorldMapService's docblock) — the server never sends what's actually there,
/// so `village` is always nil when `foggy` is true. Not Identifiable via `slot` like
/// VillageDetail.BuildingSlot — `x,y` is this struct's natural id.
struct WorldMapTile: Codable, Identifiable {
    let x: Int
    let y: Int
    let foggy: Bool
    let village: TileVillage?

    var id: String { "\(x),\(y)" }
}

/// A village as it appears ON the world map — coarser than VillageDetail (no resources/
/// buildings; those come from a separate tap-to-scout fetch, see PublicVillage below).
struct TileVillage: Codable {
    let id: Int
    let name: String
    let x: Int
    let y: Int
    let isCapital: Bool
    let population: Int
    let owner: String
    let ownerId: Int
    let tribe: String?
    let allianceId: Int?
    let allianceName: String?
    let allianceTag: String?
    let isMine: Bool
    let isAlly: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, x, y, population, owner, tribe
        case isCapital = "is_capital"
        case ownerId = "owner_id"
        case allianceId = "alliance_id"
        case allianceName = "alliance_name"
        case allianceTag = "alliance_tag"
        case isMine = "is_mine"
        case isAlly = "is_ally"
    }
}

/// Public, read-only building layout for the map's tap-to-scout preview — GET
/// /api/map/villages/{id} (Api\MapController::village(), via WorldMapService::
/// publicVillagePayload()). Deliberately thinner than VillageDetail: no resources, no hp, no
/// map/coords — this is what you can tell about ANY village by looking at it from outside,
/// not the full detail you get for your own village in VillageMapView.
struct PublicVillage: Codable {
    let id: Int
    let name: String
    let x: Int
    let y: Int
    let isCapital: Bool
    let population: Int
    let owner: String
    let tribe: String?
    let allianceName: String?
    let allianceTag: String?
    let buildings: [Building]
    let builtPlots: Int
    let totalPlots: Int

    struct Building: Codable, Identifiable {
        let slot: Int
        let buildingKey: String?
        let level: Int
        let label: String?
        let gid: Int?

        var id: Int { slot }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, x, y, population, owner, tribe, buildings, builtPlots, totalPlots
        case isCapital = "is_capital"
        case allianceName = "alliance_name"
        case allianceTag = "alliance_tag"
    }
}
