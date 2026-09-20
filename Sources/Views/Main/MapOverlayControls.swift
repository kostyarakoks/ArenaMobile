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
            overlayLink(icon: "👤", id: "profile", label: "Профиль")
            overlayLink(icon: "✉️", id: "messages", label: "Сообщения")
            overlayLink(icon: "📜", id: "quests", label: "Задания")
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
                overlayButtonLabel(icon: "🏰")
            }
        } else if villageSession.detail?.village != nil {
            // Only one village — nothing to switch TO, same disabled-nameplate treatment the
            // web header gives this state.
            overlayButtonLabel(icon: "🏰")
                .opacity(0.5)
        }
    }

    private func overlayLink(icon: String, id: String, label: String) -> some View {
        NavigationLink {
            NavDestinationView(item: NavItem(id: id, icon: icon, label: label))
        } label: {
            overlayButtonLabel(icon: icon)
        }
    }

    private func overlayButtonLabel(icon: String) -> some View {
        Text(icon)
            .font(.system(size: 19))
            .frame(width: 44, height: 44)
            .background(Color.black.opacity(0.55))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
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
