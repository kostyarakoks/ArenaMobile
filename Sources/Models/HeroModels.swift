import Foundation

/// Mirrors Api\HeroController::show()'s JSON — same EquipmentService the web Hero/Show.vue page
/// uses, see travianz-laravel/app/Http/Controllers/Api/HeroController.php.
struct HeroDetail: Codable {
    let hero: Info
    let equipment: Equipment

    struct Info: Codable {
        let name: String
        let level: Int
        let experience: Int
        let experienceForNext: Int
        let health: Int
        let unspentPoints: Int
        let pointAttack: Int
        let pointDefense: Int
        let pointOffBonus: Int
        let pointDefBonus: Int
        let isOnAdventure: Bool
        let village: String?
    }

    struct Equipment: Codable {
        let slots: [String]
        let equipped: EquippedSlots
        let owned: OwnedBySlot
        let bonusPercent: BonusPercent
        let craftable: [CraftableItem]
    }

    struct BonusPercent: Codable {
        let attack: Int
        let defense: Int
    }

    /// heroes.equipped_weapon/armor/trinket — always exactly these 3 keys (see config/equipment.
    /// php's 'slots'), so a fixed struct instead of a [String: Item?] dictionary.
    struct EquippedSlots: Codable {
        let weapon: Item?
        let armor: Item?
        let trinket: Item?
    }

    /// Same 3 fixed slots, but each holding a stack of owned-but-unequipped copies.
    struct OwnedBySlot: Codable {
        let weapon: [Item]
        let armor: [Item]
        let trinket: [Item]
    }

    /// An owned/equipped copy — EquipmentService::present()'s shape, untouched snake_case
    /// (only the wrapper fields HeroController builds itself are camelCased).
    struct Item: Codable, Identifiable, Hashable {
        let key: String
        let itemKey: String
        let slot: String
        let tier: Int
        let rarity: String
        let icon: String
        let offBonus: Int
        let defBonus: Int
        let label: String
        let description: String
        let quantity: Int

        var id: String { itemKey }

        enum CodingKeys: String, CodingKey {
            case key, slot, tier, rarity, icon, label, description, quantity
            case itemKey = "item_key"
            case offBonus = "off_bonus"
            case defBonus = "def_bonus"
        }
    }

    /// A catalog entry not yet owned, with its craft cost — HeroController::craftableCatalog(),
    /// which DOES camelCase its own output (unlike Item above, which passes EquipmentService's
    /// array straight through).
    struct CraftableItem: Codable, Identifiable, Hashable {
        let key: String
        let slot: String
        let tier: Int
        let rarity: String
        let icon: String
        let offBonus: Int
        let defBonus: Int
        let label: String
        let description: String
        let cost: [String: Int]

        var id: String { key }
    }
}
