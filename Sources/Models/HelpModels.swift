import Foundation

/// Mirrors Api\HelpController::index()'s JSON — travianz-laravel/app/Http/Controllers/Api/
/// HelpController.php, the exact same lang('game.help') content the web Help/Index.vue renders.
struct HelpContent: Codable {
    let title: String
    let subtitle: String
    let sections: [String: HelpSection]
}

struct HelpSection: Codable, Identifiable {
    let icon: String
    let title: String
    let body: [String]
    var id: String { title }
}
