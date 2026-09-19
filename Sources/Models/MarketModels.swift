import Foundation

/// Mirrors Api\MarketController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// MarketController.php. Two markets on one screen, same as the web Market/Index.vue: resource
/// offers (MarketService) and the "Предметы" item market (EquipmentService), which reuses
/// HeroDetail.Item's shape for sellableItems (EquipmentService::ownedUnequipped()) since it's
/// the exact same method Api\HeroController's 'owned' field calls.
struct MarketDetail: Codable {
    let village: VillageInfo
    let offers: [ResourceOffer]
    let mine: [MyResourceOffer]
    let underConstruction: Bool
    let itemOffers: [ItemOffer]
    let myItemOffers: [MyItemOffer]
    let sellableItems: HeroDetail.OwnedBySlot

    struct VillageInfo: Codable {
        let id: Int
        let name: String
        let wood: Int
        let clay: Int
        let iron: Int
        let crop: Int
    }

    struct ResourceOffer: Codable, Identifiable {
        let id: Int
        let seller: String
        let village: String
        let offerResource: String
        let offerAmount: Int
        let requestResource: String
        let requestAmount: Int
    }

    struct MyResourceOffer: Codable, Identifiable {
        let id: Int
        let offerResource: String
        let offerAmount: Int
        let requestResource: String
        let requestAmount: Int
    }

    /// EquipmentService::listOffers() — its own array shape, unchanged (snake_case) by the API
    /// controller, same as HeroDetail.Item above.
    struct ItemOffer: Codable, Identifiable {
        let id: Int
        let seller: String
        let village: String
        let itemKey: String
        let label: String
        let icon: String
        let rarity: String
        let priceResource: String
        let priceAmount: Int

        enum CodingKeys: String, CodingKey {
            case id, seller, village, label, icon, rarity
            case itemKey = "item_key"
            case priceResource = "price_resource"
            case priceAmount = "price_amount"
        }
    }

    /// EquipmentService::myOffers() — same note as ItemOffer above.
    struct MyItemOffer: Codable, Identifiable {
        let id: Int
        let itemKey: String
        let label: String
        let priceResource: String
        let priceAmount: Int

        enum CodingKeys: String, CodingKey {
            case id, label
            case itemKey = "item_key"
            case priceResource = "price_resource"
            case priceAmount = "price_amount"
        }
    }
}

/// The 4 tradeable resources, for pickers — same set the web app's Rule::in(...) validates.
enum GameResource: String, CaseIterable, Identifiable {
    case wood, clay, iron, crop
    var id: String { rawValue }
    var label: String {
        switch self {
        case .wood: return "Дерево"
        case .clay: return "Глина"
        case .iron: return "Железо"
        case .crop: return "Зерно"
        }
    }
    var icon: String {
        switch self {
        case .wood: return "🌲"
        case .clay: return "🧱"
        case .iron: return "⛏️"
        case .crop: return "🌾"
        }
    }
}
