import SwiftUI

/// Global resources header — pinned to the top of EVERY main screen (wired up in MainTabView via
/// `.safeAreaInset(edge: .top)`, same slot bottomDock already uses at the bottom), mirroring
/// GameLayout.vue's own always-present header on the web app (resources/js/Layouts/
/// GameLayout.vue) rather than only showing on the village map like this used to.
///
/// This is VillageMapView's old `topHeaderBar`, trimmed down: the village nameplate/switcher and
/// the profile/messages/quests action icons moved OUT to float over the map screens instead (see
/// MapOverlayControls) — those don't belong on every single screen the way the resource strip
/// does, and leaving them here would crowd a header that's now global instead of village-only.
struct GameHeaderBar: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                emblemBadge

                // Present once a village has loaded (every screen shares the same
                // VillageSession, so this fills in identically wherever you are, not just on
                // the village map).
                if let info = villageSession.detail?.village {
                    resourceBadge(image: "icon_wood", info.wood)
                    resourceBadge(image: "icon_clay", info.clay)
                    resourceBadge(image: "icon_iron", info.iron)
                    resourceBadge(image: "icon_crop", info.crop)
                }

                if let user = session.currentUser {
                    // No bespoke silver-coin art was supplied alongside the other 9 icons —
                    // keeps the 🪙 emoji fallback until one is.
                    resourceBadge("🪙", user.silver)
                    resourceBadge(image: "icon_gem", user.gold)
                }

                Spacer(minLength: 4)

                // Refreshes whichever village is currently active — the map no longer sits in
                // a ScrollView on the screens that show it, so pull-to-refresh has nothing to
                // attach to; this is the replacement, same as before.
                Button {
                    villageSession.refreshSelected(session)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(GameTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .gameOctagonBadge(cut: 8)
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

    private var emblemBadge: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [GameTheme.panelTop, GameTheme.panelBottom], startPoint: .top, endPoint: .bottom))
            Circle()
                .stroke(LinearGradient(colors: [GameTheme.amberLight, GameTheme.btnBottom], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                .padding(2)
            Circle().stroke(GameTheme.amber.opacity(0.5), lineWidth: 1).padding(6)
            Image(systemName: "shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(GameTheme.textSecondary)
        }
        .frame(width: 44, height: 44)
    }

    private func resourceBadge(_ icon: String, _ value: Int) -> some View {
        VStack(spacing: 1) {
            Text(icon).font(.system(size: 15))
            Text("\(value)").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(GameTheme.textPrimary)
        }
        .frame(width: 38, height: 36)
        .gameOctagonBadge(cut: 9)
    }

    // Same slot as the emoji overload above, painted icon art instead (see
    // Assets.xcassets/GameAssets/UI — the same 9 PNGs GameLayout.vue's RESOURCE_ICONS uses on
    // the web, sliced from the same reference sprite sheet).
    private func resourceBadge(image: String, _ value: Int) -> some View {
        VStack(spacing: 1) {
            Image(image).resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18)
            Text("\(value)").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(GameTheme.textPrimary)
        }
        .frame(width: 38, height: 36)
        .gameOctagonBadge(cut: 9)
    }
}

#Preview {
    GameHeaderBar()
        .environmentObject(AuthSession())
        .environmentObject(VillageSession())
}
