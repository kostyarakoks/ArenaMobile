import SwiftUI

/// Native port of resources/js/Components/BottomNav.vue: a custom dock plus a "Ещё" button that
/// opens a grid sheet with everything else — not a system TabView, on purpose, so the shape
/// matches the web app exactly instead of iOS's own >5-items-collapse-to-"More" behavior (which
/// would put different items behind "More" than the web version does).
struct MainTabView: View {
    @State private var selected: NavItem = .village
    @State private var showMore = false

    // Same collapse BottomNav.vue's `villageMapItem` computed does: village/map share ONE dock
    // slot, showing whichever one you're NOT currently on (tapping it switches to it) — so the
    // dock is 5 items + "Ещё" (6 buttons total), matching the web version's count, instead of
    // listing village and map as two separate always-visible slots.
    private var isOnMap: Bool { selected.id == "map" }
    private var toggleItem: NavItem { isOnMap ? .village : .map }
    private var dockItems: [NavItem] {
        [toggleItem] + NavItem.mainItems.filter { $0.id != "village" && $0.id != "map" }
    }
    private func isDockItemActive(_ item: NavItem) -> Bool {
        (item.id == "village" || item.id == "map") ? (selected.id == "village" || selected.id == "map") : item == selected
    }

    var body: some View {
        NavigationStack {
            NavDestinationView(item: selected)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomDock
        }
        .sheet(isPresented: $showMore) {
            moreSheet
                .presentationDetents([.medium, .large])
        }
    }

    private var bottomDock: some View {
        HStack(spacing: 0) {
            ForEach(dockItems) { item in
                dockButton(item: item, isActive: isDockItemActive(item)) {
                    selected = item
                }
            }
            dockButton(label: "Ещё", icon: "⋯", img: nil, isActive: showMore) {
                showMore = true
            }
        }
        .padding(.vertical, 6)
        // The bar texture + crest the user supplied (see BottomNav.vue's NAV_BAR_BG/NAV_CREST,
        // sliced by build_ios_assets.py into Assets.xcassets/Nav) — replaces the old plain
        // gradient background so the native dock matches the web app's finished look exactly,
        // not just an approximation of it.
        .background(
            Image("nav_bar_bg")
                .resizable(resizingMode: .stretch)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Image("nav_crest")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
                .offset(y: -11)
                .allowsHitTesting(false)
        }
    }

    private func dockButton(item: NavItem, isActive: Bool, action: @escaping () -> Void) -> some View {
        dockButton(label: item.label, icon: item.icon, img: item.img, isActive: isActive, action: action)
    }

    private func dockButton(label: String, icon: String, img: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Local asset art (bundled in the app — see build_ios_assets.py) when available,
                // falling back to the emoji otherwise (same fallback BottomNav.vue uses for the
                // "Деревня" toggle state and the "Ещё" spots that never got painted art).
                if let img {
                    Image(img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                } else {
                    Text(icon).font(.system(size: 20))
                }
                Text(label).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Color(red: 1, green: 0.84, blue: 0.47) : .white.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isActive ? Color.white.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var moreSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(NavItem.moreItems) { item in
                        Button {
                            selected = item
                            showMore = false
                        } label: {
                            VStack(spacing: 6) {
                                Text(item.icon).font(.system(size: 26))
                                Text(item.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(GameTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(item == selected ? GameTheme.amber.opacity(0.18) : GameTheme.panelTop.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .gameScreenBackground()
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { showMore = false }
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthSession())
}
