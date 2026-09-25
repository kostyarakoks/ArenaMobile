import SwiftUI

/// Native port of resources/js/Components/BottomNav.vue: a custom dock plus a "Ещё" button that
/// opens a grid sheet with everything else — not a system TabView, on purpose, so the shape
/// matches the web app exactly instead of iOS's own >5-items-collapse-to-"More" behavior.
///
/// ИЗМЕНЕНО: контент (NavigationStack) растянут на весь экран, а GameHeaderBar и bottomDock
/// навешены через `.safeAreaInset` — они рисуются ПОВЕРХ контента и одновременно "резервируют"
/// свою высоту в safe area. Это позволяет экранам типа VillageMapView через
/// `.ignoresSafeArea()` растянуть карту на ВЕСЬ экран, включая области под хедером и доком
/// (карта уходит под них), а обычным экранам (Рынок, Герой и т.д.) — автоматически получить
/// контент внутри безопасной зоны без каких-либо изменений с их стороны.
///
/// Раньше здесь стоял VStack из трёх рядов (хедер / NavigationStack / док). Это гарантировало,
/// что ни один экран не заедет под бары, но делало невозможным "карта заходит под хедер":
/// NavigationStack был жёстко ограничен сверху и снизу, и никакие `.ignoresSafeArea()` внутри
/// него не помогали — они игнорируются на границе контейнера, к которому применён
/// safeAreaInset снаружи.
struct MainTabView: View {
    @EnvironmentObject private var session: AuthSession
    @StateObject private var villageSession = VillageSession()

    @State private var selected: NavItem = .village
    @State private var showMore = false

    @State private var lastMapOrVillage: NavItem = .village

    private var isOnMap: Bool { selected.id == "map" }
    private var isOnMapOrVillage: Bool { selected.id == "village" || selected.id == "map" }
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
        NavigationStack {
            NavDestinationView(item: selected, selectItem: { selected = $0 })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Хедер с ресурсами — safeAreaInset сверху. Рисуется поверх контента,
        // но резервирует свою высоту в safe area, так что обычные экраны
        // (List, ScrollView) получают контент ПОД ним, а не под ним в смысле
        // "перекрыт". VillageMapView же явно игнорирует эту safe area для
        // карты — поэтому карта уходит под хедер.
        .safeAreaInset(edge: .top, spacing: 0) {
            GameHeaderBar(selectItem: { selected = $0 })
        }
        // Нижний док — safeAreaInset снизу. Аналогично: резервирует высоту
        // в safe area (обычные экраны не заезжают под док), но карта в
        // VillageMapView растягивается под него через .ignoresSafeArea().
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomDock()
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private let dockHeight: CGFloat = 74
    private let crestOverlap: CGFloat = 11

    private func bottomDock() -> some View {
        HStack(spacing: 0) {
            ForEach(dockItems) { item in
                dockButton(item: item, isActive: isDockItemActive(item)) {
                    selected = item
                }
            }
            dockButton(label: "Ещё", icon: "⋯", img: "nav_more", isActive: showMore) {
                showMore = true
            }
        }
        .frame(height: dockHeight)
        .padding(.top, crestOverlap)
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
                .allowsHitTesting(false)
        }
    }

    private func dockButton(item: NavItem, isActive: Bool, action: @escaping () -> Void) -> some View {
        dockButton(label: item.label, icon: item.icon, img: item.img, isActive: isActive, action: action)
    }

    private func dockButton(label: String, icon: String, img: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
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