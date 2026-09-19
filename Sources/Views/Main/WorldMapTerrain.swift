import SwiftUI

/// Decorative terrain for a REVEALED, empty (no village) world-map tile — the same idea as
/// resources/js/mapTerrain.js on the web side: there's no real terrain/oasis data anywhere in
/// the game, so an empty tile's look is derived purely from its own (x,y) with a deterministic
/// hash (same tile always looks the same, no flicker on reload/pan). This is Swift's own hash,
/// not a byte-for-byte port of the JS one (replicating JS's float/Int32 rounding exactly isn't
/// worth it for a purely cosmetic tile color) — same visual style and thresholds, not
/// guaranteed to pick the identical terrain kind tile-for-tile as the web map.
enum WorldMapTerrain {
    enum Kind {
        case grass, sparse, forest, hill, lake
    }

    static func kind(x: Int, y: Int) -> Kind {
        var h = UInt64(bitPattern: Int64(x)) &* 374761393 &+ UInt64(bitPattern: Int64(y)) &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        h = h ^ (h >> 16)
        let value = Int(h % 1000)

        if value < 8 { return .lake }
        if value < 45 { return .hill }
        if value < 140 { return .forest }
        if value < 320 { return .sparse }
        return .grass
    }

    static func color(for kind: Kind) -> Color {
        switch kind {
        case .grass, .sparse: return Color(red: 0.737, green: 0.867, blue: 0.549)
        case .forest: return Color(red: 0.663, green: 0.824, blue: 0.478)
        case .hill: return Color(red: 0.788, green: 0.769, blue: 0.627)
        case .lake: return Color(red: 0.561, green: 0.776, blue: 0.867)
        }
    }

    static func icon(for kind: Kind) -> String? {
        switch kind {
        case .grass: return nil
        case .sparse: return "·"
        case .forest: return "🌲"
        case .hill: return "⛰"
        case .lake: return "〰"
        }
    }
}
