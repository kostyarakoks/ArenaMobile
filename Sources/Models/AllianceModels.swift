import Foundation

/// Mirrors Api\AllianceController's JSON — travianz-laravel/app/Http/Controllers/Api/
/// AllianceController.php, same AllianceService the web Alliance/* pages use.
struct AllianceSummary: Codable, Identifiable {
    let id: Int
    let name: String
    let tag: String
    let membersCount: Int
}

struct AllianceDetail: Codable {
    let id: Int
    let name: String
    let tag: String
    let description: String?
    let leader: String?
    let members: [Member]

    struct Member: Codable, Identifiable {
        let id: Int
        let name: String
        let role: String?
        let villagesCount: Int
    }
}
