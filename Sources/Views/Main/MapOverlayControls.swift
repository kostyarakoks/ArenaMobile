import SwiftUI

/// Floating vertical button stack anchored to a map screen's trailing edge — village switcher,
/// profile, messages, quests. These used to live in VillageMapView's own header (the nameplate
/// doubled as the village switcher; gear/envelope/scroll were plain action icons) — moved out
/// here once the resources header became global (see GameHeaderBar): a header shown on every
/// screen shouldn't carry map-specific/village-specific controls, so they now float over the map
/// itself instead, the same "fixed right-3 top-1/2" floating icon stack GameLayout.vue keeps over
/// the web app's own pages.
///
/// Used by both VillageMapView and WorldMapView, so these stay reachable from either map without
/// detouring through the bottom dock's "Ещё" sheet.
struct MapOverlayControls: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    var body: some View {
        VStack(spacing: 10) {
            villageSwitcher
            overlayLink(image: "icon_gear", id: "profile", icon: "👤", label: "Профиль")
            overlayLink(image: "icon_messages", id: "messages", icon: "✉️", label: "Сообщения")
            overlayLink(image: "icon_quests", id: "quests", icon: "📜", label: "Задания")
        }
    }

    @ViewBuilder
    private var villageSwitcher: some View {
        if villageSession.villages.count > 1 {
            Menu {
                ForEach(villageSession.villages) { village in
                    Button {
                        villageSession.selectVillage(id: village.id, session)
                    } label: {
                        HStack {
                            Text(village.name + (village.isCapital ? " ★" : ""))
                            if village.id == villageSession.selectedVillageID { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                overlayButtonLabel(image: "icon_village")
            }
        } else if villageSession.detail?.village != nil {
            // Only one village — nothing to switch TO, same disabled-nameplate treatment the
            // web header gives this state.
            overlayButtonLabel(image: "icon_village")
                .opacity(0.5)
        }
    }

    private func overlayLink(image: String, id: String, icon: String, label: String) -> some View {
        NavigationLink {
            NavDestinationView(item: NavItem(id: id, icon: icon, label: label))
        } label: {
            overlayButtonLabel(image: image)
        }
    }

    // Same .tv-octagon-style plate GameHeaderBar's resource badges use (gameOctagonBadge, see
    // GameTheme.swift) instead of the plain translucent-black circle this used to be — matches
    // GameLayout.vue's own header/floating-rail buttons on the web, which got the identical
    // treatment in this round (see the RESOURCE_ICONS comment there).
    private func overlayButtonLabel(image: String) -> some View {
        Image(image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .frame(width: 44, height: 44)
            .gameOctagonBadge(cut: 9)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}

#Preview {
    MapOverlayControls()
        .environmentObject(AuthSession())
        .environmentObject(VillageSession())
        .padding()
        .background(GameTheme.background)
}
