import Foundation

/// Mirrors resources/js/Components/BottomNav.vue in the travianz-laravel web app one-for-one —
/// same icons (now the user's own painted art, bundled locally in Assets.xcassets/Nav — see
/// build_ios_assets.py — instead of emoji, matching the web version's NAV_ICONS), same labels
/// (from lang/ru/game.php's `nav` block), same split between the 6 always-visible dock items
/// and the rest tucked behind "Ещё". `village`/`map` are exposed separately (not just as array
/// entries) because MainTabView collapses them into ONE toggle dock slot, exactly like
/// BottomNav.vue's `villageMapItem` computed does on the web (see MainTabView.dockItems).
/// Each of these is still a PlaceholderScreen for now (see PlaceholderScreen.swift) — the web
/// app builds these out one real screen at a time behind app/Services/*, and the native app can
/// follow the same order once routes/api.php grows past just auth.
struct NavItem: Identifiable, Hashable {
    let id: String
    let icon: String
    let img: String?
    let label: String

    init(id: String, icon: String, img: String? = nil, label: String) {
        self.id = id
        self.icon = icon
        self.img = img
        self.label = label
    }

    // The reference screenshot only supplied art for the "Карта" state of the toggle (there's
    // no painted icon for "Деревня" — see BottomNav.vue's own comment on this), so "village"
    // keeps its emoji fallback just like the web version does.
    static let village = NavItem(id: "village", icon: "🏛️", label: "Деревня")
    static let map = NavItem(id: "map", icon: "🗺️", img: "nav_map", label: "Карта")

    static let mainItems: [NavItem] = [
        village,
        NavItem(id: "hero", icon: "🦸", img: "nav_hero", label: "Герой"),
        NavItem(id: "market", icon: "💰", img: "nav_market", label: "Рынок"),
        NavItem(id: "alliance", icon: "🛡️", img: "nav_alliance", label: "Альянс"),
        NavItem(id: "shop", icon: "🛒", img: "nav_shop", label: "Магазин"),
        map,
    ]

    static let moreItems: [NavItem] = [
        NavItem(id: "fields", icon: "🌾", label: "Поля"),
        NavItem(id: "rally_point", icon: "⚔️", label: "Площадь сбора"),
        NavItem(id: "commanders", icon: "🧙", label: "Полководцы"),
        NavItem(id: "arena", icon: "🏟️", label: "Арена"),
        NavItem(id: "backpack", icon: "🎒", label: "Рюкзак"),
        NavItem(id: "reports", icon: "📋", label: "Отчёты"),
        NavItem(id: "messages", icon: "✉️", label: "Сообщения"),
        NavItem(id: "tech_tree", icon: "🔬", label: "Технологии"),
        NavItem(id: "research", icon: "🧪", label: "Исследования"),
        NavItem(id: "statistics", icon: "📈", label: "Статистика"),
        NavItem(id: "quests", icon: "📜", label: "Задания"),
        NavItem(id: "help", icon: "❓", label: "Помощь"),
        NavItem(id: "profile", icon: "👤", label: "Профиль"),
    ]
}
