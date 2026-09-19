import Foundation

/// Mirrors Api\ReportController's JSON — travianz-laravel/app/Http/Controllers/Api/
/// ReportController.php, same BattleReport model the web Reports/* pages use.
struct ReportSummary: Codable, Identifiable {
    let id: Int
    let type: String
    let attackerWon: Bool
    let attacker: String?
    let defender: String?
    let attackerVillage: String?
    let defenderVillage: String?
    let isRead: Bool
    let createdAt: String
    let iAmAttacker: Bool
    let captured: Bool
}

struct ReportDetail: Decodable {
    let id: Int
    let type: String
    let attackerWon: Bool
    let attacker: String?
    let defender: String?
    let attackerVillage: String?
    let defenderVillage: String?
    /// BattleReport.result is a free-form JSON column (loot, casualties, ...) — rendered as
    /// pretty-printed JSON rather than modeled field-by-field, since its shape varies by report
    /// type (attack/raid/reinforce/scout/...) and the web app itself just dumps it into a
    /// dedicated Vue component per type. Decoded via JSONSerialization, not Codable, since its
    /// shape isn't fixed.
    let resultJSON: String
    let createdAt: String
    let iAmAttacker: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, attacker, defender, attackerVillage, defenderVillage, createdAt, iAmAttacker
        case attackerWon
        case result
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        attackerWon = try c.decode(Bool.self, forKey: .attackerWon)
        attacker = try c.decodeIfPresent(String.self, forKey: .attacker)
        defender = try c.decodeIfPresent(String.self, forKey: .defender)
        attackerVillage = try c.decodeIfPresent(String.self, forKey: .attackerVillage)
        defenderVillage = try c.decodeIfPresent(String.self, forKey: .defenderVillage)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        iAmAttacker = try c.decode(Bool.self, forKey: .iAmAttacker)

        if let value = try? c.decode(AnyDecodableValue.self, forKey: .result) {
            resultJSON = value.prettyPrinted()
        } else {
            resultJSON = "{}"
        }
    }
}

/// Minimal untyped-JSON decoder, just enough to round-trip BattleReport.result's free-form
/// shape into a readable string (see ReportDetail.resultJSON above).
enum AnyDecodableValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: AnyDecodableValue])
    case array([AnyDecodableValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: AnyDecodableValue].self) { self = .object(v); return }
        if let v = try? c.decode([AnyDecodableValue].self) { self = .array(v); return }
        self = .null
    }

    func prettyPrinted(indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "да" : "нет"
        case .null: return "—"
        case .array(let items):
            return items.map { "\(pad)- \($0.prettyPrinted(indent: indent + 1))" }.joined(separator: "\n")
        case .object(let dict):
            return dict.keys.sorted().map { key in
                "\(pad)\(key): \(dict[key]!.prettyPrinted(indent: indent + 1))"
            }.joined(separator: "\n")
        }
    }
}
