import Foundation

/// Mirrors the JSON shape returned by AuthController::userPayload() on the Laravel side
/// (app/Http/Controllers/Api/AuthController.php in the travianz-laravel repo) — keep the two in
/// sync if you add fields there.
struct GameUser: Codable, Equatable {
    let id: Int
    let name: String
    let email: String
    let tribe: String?
    let locale: String?
    let gold: Int
    let silver: Int
    let arenaPoints: Int
    let isAdmin: Bool
    let allianceId: Int?

    // Flattened server-computed avatar info (Api\AuthController::avatarPayload()) — mirrors
    // PlayerAvatar.vue's own three-way fallback (uploaded image / emoji-on-colour preset /
    // plain initial letter), precomputed server-side so this model doesn't need its own copy
    // of config('avatars.presets') or storage-URL building logic. See GameHeaderBar's
    // AvatarBadge for the SwiftUI counterpart of PlayerAvatar.vue.
    let avatarKind: String // "upload" | "preset" | "initial"
    let avatarUrl: String?
    let avatarEmoji: String?
    let avatarColor: String?
    let avatarInitial: String

    enum CodingKeys: String, CodingKey {
        case id, name, email, tribe, locale, gold, silver
        case arenaPoints = "arena_points"
        case isAdmin = "is_admin"
        case allianceId = "alliance_id"
        case avatarKind = "avatar_kind"
        case avatarUrl = "avatar_url"
        case avatarEmoji = "avatar_emoji"
        case avatarColor = "avatar_color"
        case avatarInitial = "avatar_initial"
    }
}

/// One entry of the preset avatar gallery — mirrors config('avatars.presets') on the Laravel
/// side (key → emoji + background colour), served to the app via GET /api/avatar-presets.
struct AvatarPreset: Codable, Identifiable, Equatable {
    let key: String
    let emoji: String
    let color: String
    var id: String { key }
}
