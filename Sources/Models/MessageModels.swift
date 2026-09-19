import Foundation

/// Mirrors Api\MessageController's JSON — travianz-laravel/app/Http/Controllers/Api/
/// MessageController.php.
struct MessageSummary: Codable, Identifiable {
    let id: Int
    let subject: String
    let sender: String
    let recipient: String
    let readAt: String?
    let createdAt: String
}

struct MessageDetail: Codable {
    let id: Int
    let subject: String
    let body: String
    let sender: String
    let recipient: String
    let createdAt: String
    let isMine: Bool
}

struct GameEventSummary: Codable, Identifiable {
    let id: Int
    let type: String
    let text: String
    let reportId: Int?
    let createdAt: String
}
