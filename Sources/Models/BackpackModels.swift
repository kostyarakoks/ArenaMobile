import Foundation

/// Mirrors Api\BackpackController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// BackpackController.php, same InventoryService the web Backpack/Index.vue page uses.
/// InventoryService::grouped()'s own array shape (snake_case), category => [item].
struct BackpackResponse: Codable {
    let items: [String: [BackpackItem]]
}

struct BackpackItem: Codable, Identifiable {
    let itemKey: String
    let label: String
    let icon: String?
    let description: String?
    let quantity: Int
    let usable: Bool

    var id: String { itemKey }

    enum CodingKeys: String, CodingKey {
        case label, icon, description, quantity, usable
        case itemKey = "item_key"
    }
}

/// ShopItem::CATEGORIES — fixed display order, same as the web Backpack/Index.vue tabs.
enum BackpackCategory: String, CaseIterable, Identifiable {
    case resources, speedup, bonus, equipment, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .resources: return "Ресурсы"
        case .speedup: return "Ускорения"
        case .bonus: return "Бонусы"
        case .equipment: return "Снаряжение"
        case .other: return "Прочее"
        }
    }
}
