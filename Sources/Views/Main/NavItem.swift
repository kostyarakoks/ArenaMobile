import Foundation

/// Mirrors resources/js/Components/BottomNav.vue in the travianz-laravel web app one-for-one —
/// same icons, same labels (from lang/ru/game.php's `nav` block), same split between the 6
/// always-visible dock items and the rest tucked behind "Ещё". Each of these is still a
/// PlaceholderScreen for now (see PlaceholderScreen.swift) — the web app builds these out one
/// real screen at a time behind app/Services/*, and the native app can follow the same order
/// once routes/api.php grows past just auth.
struct NavItem: Identifiable, Hashable {
    let id: String
    let icon: String
    let label: String

    static let mainItems: [NavItem] = [
        NavItem(id: "village", icon: "🏛️", label: "Деревня"),
        NavItem(id: "hero", icon: "🦸", label: "Герой"),
        NavItem(id: "market", icon: "💰", label: "Рынок"),
        NavItem(id: "alliance", icon: "🛡️", label: "Альянс"),
        NavItem(id: "shop", icon: "🛒", label: "Магазин"),
        NavItem(id: "map", icon: "🗺️", label: "Карта"),
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
