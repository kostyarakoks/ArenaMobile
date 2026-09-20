import SwiftUI

/// What each nav item (see NavItem.swift) opens. Most are still plain placeholders — real
/// content lands here screen by screen as routes/api.php grows past auth. "Профиль", "Деревня"
/// and "Карта" are wired to real data already (GameUser from AuthSession, VillageMapView's and
/// WorldMapView's own network calls) — working end-to-end examples of the pattern for whichever
/// tab gets built out next.
struct NavDestinationView: View {
    let item: NavItem
    // Lets a destination switch MainTabView's own active tab directly (currently used by
    // WorldMapView's "tap your own village -> jump straight into it" shortcut, mirroring the
    // web app's router.visit(route('village.buildings', ...))) — optional so every other call
    // site (NavigationLink pushes from MapOverlayControls, the "Ещё" sheet, previews) doesn't
    // need to supply one.
    var selectItem: ((NavItem) -> Void)? = nil

    var body: some View {
        switch item.id {
        case "profile":
            ProfileScreen()
        case "village":
            VillageMapView(selectItem: { selectItem?($0) })
        case "map":
            WorldMapView(onOwnVillageSelected: { selectItem?(.village) }, selectItem: { selectItem?($0) })
        case "hero":
            HeroView()
        case "market":
            MarketView()
        case "alliance":
            AllianceView()
        case "shop":
            ShopView()
        case "rally_point":
            RallyPointView()
        case "commanders":
            CommandersView()
        case "arena":
            ArenaView()
        case "backpack":
            BackpackView()
        case "reports":
            ReportsView()
        case "messages":
            MessagesView()
        case "research":
            ResearchView()
        case "tech_tree":
            TechTreeView()
        case "statistics":
            StatisticsView()
        case "quests":
            QuestsView()
        case "help":
            HelpView()
        default:
            PlaceholderScreen(item: item)
        }
    }
}

private struct PlaceholderScreen: View {
    let item: NavItem

    var body: some View {
        VStack(spacing: 16) {
            Text(item.icon).font(.system(size: 56))
            Text(item.label).font(.title2.bold()).foregroundStyle(GameTheme.amber)
            Text("Экран «\(item.label)» ещё не подключён к данным игры — здесь появится то же самое, что вы видите на этой вкладке в веб-версии.")
                .font(.subheadline)
                .foregroundStyle(GameTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gameScreenBackground()
        .navigationTitle(item.label)
    }
}

private struct ProfileScreen: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        List {
            if let user = session.currentUser {
                Section("Игрок") {
                    LabeledContent("Имя", value: user.name)
                    LabeledContent("Email", value: user.email)
                    if let tribe = user.tribe { LabeledContent("Племя", value: tribe) }
                }
                Section("Ресурсы") {
                    LabeledContent("Золото", value: "\(user.gold)")
                    LabeledContent("Серебро", value: "\(user.silver)")
                    LabeledContent("Очки арены", value: "\(user.arenaPoints)")
                }
            }

            Section {
                Button(role: .destructive) {
                    session.logout()
                } label: {
                    Text("Выйти")
                }
            }
        }
        .navigationTitle("Профиль")
    }
}

#Preview {
    NavigationStack {
        NavDestinationView(item: NavItem.mainItems[0])
    }
    .environmentObject(AuthSession())
    .environmentObject(VillageSession())
}
