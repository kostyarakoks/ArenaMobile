import SwiftUI

/// Global resources header — pinned to the top of EVERY main screen (wired up in MainTabView via
/// `.safeAreaInset(edge: .top)`, same slot bottomDock already uses at the bottom), mirroring
/// GameLayout.vue's own always-present header on the web app (resources/js/Layouts/
/// GameLayout.vue) rather than only showing on the village map like this used to.
///
/// Pared down to exactly two things per an explicit request: the player's own avatar, and the
/// four base resources. Everything else that used to live here — silver/gold currency, the
/// manual refresh button, and (from an earlier round) the village nameplate/switcher and
/// profile/messages/quests action icons — now lives elsewhere (MapOverlayControls for the
/// latter) or nowhere on this screen at all, on purpose: this header's only job now is "who am I
/// and what do I have", the same minimal always-visible strip the reference art shows.
struct GameHeaderBar: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                AvatarBadge(user: session.currentUser)

                // Present once a village has loaded (every screen shares the same
                // VillageSession, so this fills in identically wherever you are, not just on
                // the village map).
                if let info = villageSession.detail?.village {
                    resourceBadge(image: "icon_wood", info.wood)
                    resourceBadge(image: "icon_clay", info.clay)
                    resourceBadge(image: "icon_iron", info.iron)
                    resourceBadge(image: "icon_crop", info.crop)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(
            LinearGradient(colors: [GameTheme.panelTop, GameTheme.background], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GameTheme.amber.opacity(0.35)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .top)
        )
    }

    // Wide cut-corner plate — icon left, big bold number right, no name label — mirroring the
    // reference art the user supplied (and GameLayout.vue's matching redesign on the web this
    // same round) instead of the old narrow icon-on-top/number-below square badge.
    private func resourceBadge(image: String, _ value: Int) -> some View {
        HStack(spacing: 6) {
            Image(image).resizable().aspectRatio(contentMode: .fit).frame(width: 26, height: 26)
            Text("\(value)").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(GameTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .gameOctagonBadge(cut: 10)
    }
}

/// Native counterpart of PlayerAvatar.vue's three-way fallback (uploaded image / emoji-on-colour
/// preset / plain initial letter) — reads the flattened avatar_kind/avatar_url/avatar_emoji/
/// avatar_color/avatar_initial fields Api\AuthController::avatarPayload() now sends, so this
/// view never needs its own copy of config('avatars.presets') or storage-URL building logic.
struct AvatarBadge: View {
    let user: GameUser?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            switch user?.avatarKind {
            case "upload":
                if let urlString = user?.avatarUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            initialFace
                        }
                    }
                } else {
                    initialFace
                }
            case "preset":
                ZStack {
                    Circle().fill(Color(hex: user?.avatarColor ?? ""))
                    Text(user?.avatarEmoji ?? "?").font(.system(size: size * 0.46))
                }
            default:
                initialFace
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(
                LinearGradient(colors: [GameTheme.amberLight, GameTheme.btnBottom], startPoint: .top, endPoint: .bottom),
                lineWidth: 3
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }

    private var initialFace: some View {
        ZStack {
            GameTheme.panelBottom
            Text(user?.avatarInitial ?? "?")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    GameHeaderBar()
        .environmentObject(AuthSession())
        .environmentObject(VillageSession())
}
