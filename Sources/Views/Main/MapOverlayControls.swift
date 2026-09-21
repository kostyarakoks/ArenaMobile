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
///
/// Профиль/Сообщения/Задания used to open via `NavigationLink` (a real push onto the app's one
/// shared `NavigationStack`, owned by MainTabView). That's a second, independent navigation
/// mechanism alongside MainTabView's own `selected = item` dock/"Ещё" switching — and mixing the
/// two broke navigation: pushing from here left `selected` untouched, so every subsequent
/// dock/"Ещё" tap silently changed `selected` underneath a still-visible pushed screen instead of
/// showing anything, until the player manually hit the system back button (reported: "если
/// перешел с карты в профиль, то больше ни какие окна не открываются"). Fixed by routing these
/// through the SAME `selectItem` callback the dock/"Ещё" sheet already use — see MainTabView's
/// `selected = item` and NavDestinationView's `selectItem` — so there's only ever one navigation
/// mechanism for the whole signed-in app, and this view no longer needs its own NavigationStack
/// entry at all.
struct MapOverlayControls: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    /// Switches MainTabView's own active tab — passed down from VillageMapView/WorldMapView,
    /// which get it from NavDestinationView's own `selectItem` (see MainTabView.swift).
    var selectItem: (NavItem) -> Void = { _ in }

    var body: some View {
        // "карта тоже скрывается под хедером и футером" (this round: the icon rail's bottom-most
        // button rendering under/behind the bottom dock) — placing this stack via a plain
        // `.overlay(alignment: .trailing)` at the call site centers it vertically within
        // whatever frame that call site's own outer view resolved to, and (same root cause
        // ZoomableMapContainer's own doc comment already covers for the map canvas itself)
        // there's no guarantee that frame was actually the safe sub-rect rather than the full
        // screen bounds — centering against the taller one pushes the last button below the real
        // safe bottom edge. Wrapping in a GeometryReader and subtracting `.safeAreaInsets`
        // explicitly, the same technique ZoomableMapContainer already uses, sidesteps the
        // question entirely: if the ambient proposal was already safe-sized this is a no-op
        // (insets read as ~0); if it wasn't, this still lands the stack in the true safe area.
        GeometryReader { outer in
            let safeHeight = max(0, outer.size.height - outer.safeAreaInsets.top - outer.safeAreaInsets.bottom)
            buttonStack
                .position(
                    x: outer.size.width - outer.safeAreaInsets.trailing - 22,
                    y: outer.safeAreaInsets.top + safeHeight / 2
                )
        }
    }

    private var buttonStack: some View {
        VStack(spacing: 10) {
            villageSwitcher
            // "кнопку «поля» вынести из общего в карту, таже добавить сами поля" — used to sit
            // only in the "Ещё" sheet (NavItem.moreItems) as a dead PlaceholderScreen; moved
            // out of there entirely (see NavItem.swift) and into this map-screen button stack
            // instead, now opening a real screen (FieldsMapView.swift).
            overlayButton(image: "icon_crop", id: "fields", icon: "🌾", label: "Поля")
            overlayButton(image: "icon_gear", id: "profile", icon: "👤", label: "Профиль")
            overlayButton(image: "icon_messages", id: "messages", icon: "✉️", label: "Сообщения")
            overlayButton(image: "icon_quests", id: "quests", icon: "📜", label: "Задания")
        }
    }

    // "кристаллы разместить под хедером с правой стороны" — moved out of this floating
    // map-only stack (crystals used to be invisible on every screen except the two maps) into
    // GameHeaderBar's own second row, visible everywhere. See GameHeaderBar.swift's crystalPill.

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

    private func overlayButton(image: String, id: String, icon: String, label: String) -> some View {
        Button {
            selectItem(NavItem(id: id, icon: icon, label: label))
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
