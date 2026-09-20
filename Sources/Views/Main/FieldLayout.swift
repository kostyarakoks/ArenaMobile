import Foundation

/// Swift copy of resources/js/villageMap.js's FIELD_COORDS/FIELD_MAP_VIEWBOX — the classic
/// 18-tile resource-field layout ("Поля"/dorf1), used by FieldsMapView. Keep in sync with
/// villageMap.js if that ever changes (see VillageLayout's own copy of this same disclaimer
/// for the building-plot layout).
enum FieldLayout {
    static let viewboxWidth = 300.0
    static let viewboxHeight = 264.0

    static let coords: [Int: (cx: Double, cy: Double)] = [
        1: (101, 33), 2: (165, 32), 3: (224, 46),
        4: (46, 63), 5: (138, 74), 6: (203, 94),
        7: (262, 86), 8: (31, 117), 9: (83, 110),
        10: (214, 142), 11: (269, 146), 12: (42, 171),
        13: (93, 164), 14: (160, 184), 15: (239, 199),
        16: (87, 217), 17: (140, 231), 18: (190, 232),
    ]

    /// villageMap.js's FIELDS_BACKGROUND ('/game-assets/img/g/f1.jpg') — unlike VillageLayout's
    /// 4 classic village backgrounds, this one isn't bundled locally (only one variant exists,
    /// and build_ios_assets.py never picked it up), so FieldsMapView always AsyncImage-fetches
    /// it against whatever server the player logged into, with a plain background-color
    /// fallback while it loads/if it fails.
    static let backgroundPath = "/game-assets/img/g/f1.jpg"
}
