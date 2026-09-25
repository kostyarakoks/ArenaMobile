import SwiftUI

struct NavDestinationView: View {
    let item: NavItem
    var selectItem: ((NavItem) -> Void)? = nil

    var body: some View {
        Group {
            switch item.id {
            case "profile":
                ProfileScreen()
            // case "village" УБРАН: MainTabView при `selected.id == "village"`
            // рендерит VillageMapView() напрямую, минуя NavDestinationView.
            case "map":
                WorldMapView(onOwnVillageSelected: { selectItem?(.village) }, selectItem: { selectItem?($0) })
            case "fields":
                FieldsMapView(selectItem: { selectItem?($0) })
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
        .gameNavBarHidden()
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
        .withScreenTitle { ScreenTitleBar(item.label) }
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
                    LabeledContent("Кристаллы", value: "\(user.gold)")
                    LabeledContent("Очки арены", value: "\(user.arenaPoints)")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await session.logout() }
                } label: {
                    Text("Выйти")
                }
            }
        }
        .gameListBackground()
        .withScreenTitle { ScreenTitleBar("Профиль") }
    }
}

#Preview {
    NavigationStack {
        NavDestinationView(item: NavItem.mainItems[0])
    }
    .environmentObject(AuthSession())
    .environmentObject(VillageSession())
}