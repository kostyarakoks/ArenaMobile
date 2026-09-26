import Foundation

/// Swift copy of resources/js/villageMap.js's BUILDING_COORDS/BUILDING_MAP_VIEWBOX and
/// buildingsBackground() — the classic 21-plot village-centre layout, used whenever a village
/// has no admin-uploaded map template (Api\VillageController::show()'s `map` comes back with
/// nil coords/background). Keep this in sync with villageMap.js if that ever changes; it's a
/// static, rarely-changing layout, so duplicating it here (rather than fetching it from the
/// server) keeps VillageMapView working even the very first time it loads.
enum VillageLayout {
    static let viewboxWidth = 940.0
    static let viewboxHeight = 1672.0

    static let coords: [Int: (cx: Double, cy: Double)] = [
        1: (190.5, 191.2), 2: (173.5, 66.2), 3: (233.5, 56.2),
        4: (307.5, 69.2), 5: (364.5, 117.2), 6: (51.5, 129.2),
        7: (134.5, 137.2), 8: (219.6, 101.6), 9: (374.5, 156.2),
        10: (39.5, 199.2), 11: (166.5, 164.2), 12: (129.5, 189.2),
        13: (379.5, 216.2), 14: (59.5, 238.2), 15: (204.5, 232.2),
        16: (327.5, 251.2), 17: (132.5, 273.2), 18: (259.5, 284.2),
        19: (117.5, 306.2), 20: (236.5, 316.2), 21: (289.0, 189.6),
    ]

    /// Mirrors villageMap.js's buildingsBackground(tribe, wallLevel) — same asset paths,
    /// resolved against whatever server the player logged into (see VillageMapView). Used as a
    /// key into backgroundAssetName(forPath:) below, and — for a village with an admin-uploaded
    /// custom map template — as the literal network path VillageMapView falls back to fetching.
    static func backgroundPath(tribe: String?, wallLevel: Int) -> String {
        guard wallLevel > 0 else { return "/game-assets/img/g/bg0.jpg" }
        switch tribe {
        case "roman": return "/game-assets/img/g/bg11.jpg"
        case "teuton": return "/game-assets/img/g/bg12.jpg"
        default: return "/game-assets/img/g/bg1.jpg"
        }
    }

    /// Maps one of the 4 classic background paths above to the name of its imageset, bundled
    /// straight into the app by build_ios_assets.py (Assets.xcassets/GameAssets/Backgrounds) —
    /// this is the fix for "не грузилось долго с сервера": VillageMapView renders Image(name)
    /// instantly from the app bundle for these instead of AsyncImage-fetching a jpg from the
    /// server on every single map view. Only these 4 well-known assets are bundled, so a village
    /// with an admin-uploaded custom map template (an arbitrary, per-village image the app can't
    /// know about ahead of time) correctly falls through to nil, and VillageMapView keeps using
    /// AsyncImage for that one case.
    static func backgroundAssetName(forPath path: String) -> String? {
        switch path {
        case "/game-assets/img/g/bg0.jpg": return "bg0"
        case "/game-assets/img/g/bg1.jpg": return "bg1"
        case "/game-assets/img/g/bg11.jpg": return "bg11"
        case "/game-assets/img/g/bg12.jpg": return "bg12"
        default: return nil
        }
    }
}
