import SwiftUI

/// Native port of resources/js/Components/BottomNav.vue: a custom dock plus a "Ещё" button that
/// opens a grid sheet with everything else — not a system TabView, on purpose, so the shape
/// matches the web app exactly instead of iOS's own >5-items-collapse-to-"More" behavior (which
/// would put different items behind "More" than the web version does).
struct MainTabView: View {
    @EnvironmentObject private var session: AuthSession
    // One instance for the whole signed-in session — see VillageSession.swift. Injected below
    // so GameHeaderBar, VillageMapView, WorldMapView and MapOverlayControls all read/write the
    // same active-village state instead of each fetching their own copy.
    @StateObject private var villageSession = VillageSession()

    @State private var selected: NavItem = .village
    @State private var showMore = false

    // Remembers whichever of village/map was last actually shown, so the toggle slot has
    // something to return to once you've navigated away to a third screen (profile, quests,
    // etc.) — see toggleItem below. Starts at .village since that's `selected`'s own initial
    // value.
    @State private var lastMapOrVillage: NavItem = .village

    // Same collapse BottomNav.vue's `villageMapItem` computed does: village/map share ONE dock
    // slot, showing whichever one you're NOT currently on (tapping it switches to it) — so the
    // dock is 5 items + "Ещё" (6 buttons total), matching the web version's count, instead of
    // listing village and map as two separate always-visible slots.
    private var isOnMap: Bool { selected.id == "map" }
    private var isOnMapOrVillage: Bool { selected.id == "village" || selected.id == "map" }
    // While on village or map, the toggle offers the OTHER one of the pair (unchanged
    // behavior). From any other screen (profile, quests, ...) it used to always fall back to
    // .map regardless of what you'd been looking at — reported as: "кнопка «город» и «карта»
    // меняються только если включен город или карта, в остальных случаях... если ушел с карты,
    // то при нажатие на кнопку я должен вернуться на карту, так же и с городом". Fixed by
    // falling back to whichever of the two was last actually active instead of hardcoding .map.
    private var toggleItem: NavItem {
        isOnMapOrVillage ? (isOnMap ? .village : .map) : lastMapOrVillage
    }
    private var dockItems: [NavItem] {
        [toggleItem] + NavItem.mainItems.filter { $0.id != "village" && $0.id != "map" }
    }
    private func isDockItemActive(_ item: NavItem) -> Bool {
        (item.id == "village" || item.id == "map") ? (selected.id == "village" || selected.id == "map") : item == selected
    }

    var body: some View {
        // "область экрана должна быть разделена на три части: верх 1/7, низ 1/7, средняя часть
        // 5/7" — an exact proportional split, not "whatever GameHeaderBar/bottomDock naturally
        // measure out to" (the previous approach, which reserved exactly each bar's own content
        // height — correct in the sense that content never sat BEHIND a bar, but not this exact
        // 1/7 : 5/7 : 1/7 ratio the design calls for). RootView renders MainTabView directly
        // with no GeometryReader of its own in between, so this one sees the true full-screen
        // proposal — same property ZoomableMapContainer's own GeometryReader already relies on.
        GeometryReader { screen in
            let barHeight = screen.size.height / 7

            NavigationStack {
                // `selectItem` lets a screen further down (currently WorldMapView, tapping your
                // own village) switch the active tab itself — the native equivalent of the web
                // app's router.visit(route('village.buildings', ...)) jump, since there's no
                // URL/route to navigate to here, just this same @State this view already owns.
                NavDestinationView(item: selected, selectItem: { selected = $0 })
            }
            // Global resources header — see GameHeaderBar's own doc comment for why this moved
            // here from being VillageMapView's own private header. Forced to exactly `barHeight`
            // (1/7 of the screen) rather than sized to its own content, per the spec above.
            .safeAreaInset(edge: .top, spacing: 0) {
                GameHeaderBar(selectItem: { selected = $0 }, height: barHeight)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomDock(height: barHeight)
            }
            .environmentObject(villageSession)
            .sheet(isPresented: $showMore) {
                moreSheet
                    .presentationDetents([.medium, .large])
            }
            .task {
                await villageSession.loadIfNeeded(session)
            }
            .onChange(of: selected) { newValue in
                if newValue.id == "village" || newValue.id == "map" {
                    lastMapOrVillage = newValue
                }
            }
        }
    }

    // Fixed row height, taller than the plain content needs — the icon row centers inside it
    // (see dockButton's own maxHeight: .infinity) while the bar texture behind it bleeds on
    // down through the home-indicator safe area (.ignoresSafeArea below), so the icons land in
    // the visual middle of the whole painted bar instead of hugging its top edge.
    private let dockHeight: CGFloat = 74
    // The nav_crest emblem pokes 11pt ABOVE the dock's own row via a decorative overlay (a
    // common bottom-bar flourish — see below), which doesn't count toward the icon row's own
    // `dockHeight`. Reserved via `.padding(.top, crestOverlap)` so it renders inside the bar's
    // own layout instead of poking out past whatever total height this bar is given.
    private let crestOverlap: CGFloat = 11

    // "нижняя часть 1/7 экрана" — takes the exact height MainTabView computed (1/7 of the
    // screen) and stretches this bar's own background to fill ALL of it, not just its natural
    // (icon row + crest) content size — see GameHeaderBar's matching `height` parameter for the
    // identical reasoning. Content is top-aligned within that height (closest to the game
    // content above it), so any slack lands at the very bottom, near the home indicator, where
    // extra breathing room reads as intentional rather than as a gap.
    private func bottomDock(height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(dockItems) { item in
                dockButton(item: item, isActive: isDockItemActive(item)) {
                    selected = item
                }
            }
            // nav_more.imageset was already bundled (build_ios_assets.py) but never wired up —
            // "Ещё" was still falling back to the "⋯" emoji.
            dockButton(label: "Ещё", icon: "⋯", img: "nav_more", isActive: showMore) {
                showMore = true
            }
        }
        .frame(height: dockHeight)
        .padding(.top, crestOverlap)
        .frame(height: height, alignment: .top)
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
            // No `.offset` needed any more — the `.padding(.top, crestOverlap)` above already
            // shifted this view's own top edge up by exactly the 11pt the crest used to be
            // offset by, so aligning it flush to THIS (now taller) view's top edge lands it in
            // the identical visual spot as before, just within the reserved safe area now
            // instead of poking out past it.
            Image("nav_crest")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
                .allowsHitTesting(false)
        }
    }

    private func dockButton(item: NavItem, isActive: Bool, action: @escaping () -> Void) -> some View {
        dockButton(label: item.label, icon: item.icon, img: item.img, isActive: isActive, action: action)
    }

    private func dockButton(label: String, icon: String, img: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                // Local asset art (bundled in the app — see build_ios_assets.py) when available,
                // falling back to the emoji otherwise (same fallback BottomNav.vue uses for the
                // "Деревня" toggle state).
                if let img {
                    Image(img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 31, height: 31)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                } else {
                    Text(icon).font(.system(size: 24))
                }
                Text(label).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Color(red: 1, green: 0.84, blue: 0.47) : .white.opacity(0.75))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
            // See AppVersion.swift's own doc comment for why this shows here and on the splash
            // screen — "добавить в приложение номер версии сборки при загрузки и при открытие
            // «еще»".
            .safeAreaInset(edge: .bottom) {
                Text(AppVersion.displayString)
                    .font(.caption2)
                    .foregroundStyle(GameTheme.textMuted)
                    .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthSession())
}
