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
        // "так же скрывается под хедером" — wrapped in a Group so ONE `.gameNavBarHidden()`
        // (see GameTheme.swift's own doc comment) covers every branch below, instead of each of
        // the 18+ screens needing to remember to hide the native bar individually the way only
        // the three map screens used to. The four screens that had a REAL action button living
        // in that native bar (MarketView, AllianceView, RallyPointView, MessagesView) now render
        // their own in-content ScreenTitleBar instead — see each of those files.
        Group {
            switch item.id {
            case "profile":
                ProfileScreen()
            case "village":
                VillageMapView(selectItem: { selectItem?($0) })
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
                    // "в профиле убрать серебро, золото переименовать в кристалл" — `user.gold`
                    // is the same premium-currency balance GameHeaderBar's crystalPill already
                    // shows as 💎 (see its own doc comment) — the underlying field is still named
                    // "gold" (inherited from the original TravianZ schema this was reskinned
                    // from), but the game itself never surfaces a "золото" currency anywhere else
                    // — only "кристаллы" — so this was just a leftover label. "Серебро" (silver)
                    // isn't used by any current game system at all and is dropped outright rather
                    // than relabeled.
                    LabeledContent("Кристаллы", value: "\(user.gold)")
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
