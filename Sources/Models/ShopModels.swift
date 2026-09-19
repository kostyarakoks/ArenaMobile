import Foundation

/// Mirrors Api\ShopController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// ShopController.php, same ShopService the web Shop/Index.vue page uses.
struct ShopDetail: Codable {
    let crystals: Int
    let plusActive: Bool
    let packages: [Package]
    let plusQueueCost: Int
    let plusQueueTempCost: Int
    let plusQueueTempDays: Int
    let plusTempUntil: String?
    let items: [ShopCatalogItem]

    struct Package: Codable, Identifiable {
        let id: Int
        let crystals: Int
        let priceLabel: String
    }
}

struct ShopCatalogItem: Codable, Identifiable {
    let id: Int
    let key: String
    let category: String
    let label: String
    let icon: String?
    let description: String?
    let costCrystals: Int
    let stockLimit: Int?
    let stockRemaining: Int?
    let inStock: Bool
}
