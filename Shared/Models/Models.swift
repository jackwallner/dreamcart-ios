import Foundation

// Wire models mirroring the Supabase schema. Snake_case decoded via a shared
// decoder (see SupabaseClient.decoder).

struct Brand: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let tagline: String
    let accentHex: String
    let bgHex: String
    let sort: Int
}

struct Product: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let brandId: String
    let name: String
    let category: String
    let slot: String
    let styleTags: [String]
    let colorName: String
    let price: Int
    let rarity: String
    let description: String
    let imageUrl: String
    let dropDate: String?

    var rarityKind: Rarity { Rarity(rarity) }
}

// Product joined with its brand row (PostgREST embed).
struct ProductWithBrand: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let brandId: String
    let name: String
    let category: String
    let slot: String
    let styleTags: [String]
    let colorName: String
    let price: Int
    let rarity: String
    let description: String
    let imageUrl: String
    let dropDate: String?
    let brands: Brand?

    var rarityKind: Rarity { Rarity(rarity) }
}

// From the me() RPC — the authoritative snapshot of the signed-in user.
struct MeSnapshot: Codable, Sendable {
    let id: String
    let displayName: String
    let coins: Int
    let streak: Int
    let bestStreak: Int
    let isPlus: Bool
    let lifetimeSpent: Int
    let itemsOwned: Int
    let canClaimDaily: Bool
    let canSpin: Bool
    let lastDailyClaim: String?
    let lastSpinDate: String?
}

extension MeSnapshot {
    /// The streak as it stands on `now`. The server only resets `streak` when the
    /// next claim lands, so after a missed day `me()` still reports the old count
    /// while claiming now starts a new streak at 1. A streak is alive when the
    /// last claim was today or yesterday, by the server's UTC day.
    func liveStreak(now: Date = Date()) -> Int {
        guard streak > 0, let lastDailyClaim else { return 0 }
        let alive = [UTCDay.string(now), UTCDay.string(now.addingTimeInterval(-86_400))]
        return alive.contains(lastDailyClaim) ? streak : 0
    }
}

/// A calendar day as the database writes a `date` ("YYYY-MM-DD"), in UTC like
/// its `current_date`.
enum UTCDay {
    static func string(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian)
            .dateComponents(in: TimeZone(secondsFromGMT: 0) ?? .gmt, from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

struct DailyResult: Codable, Sendable {
    let ok: Bool
    let reason: String?
    let granted: Int?
    let coins: Int
    let streak: Int?
    let weeklyBonus: Bool?
}

struct SpinResult: Codable, Sendable {
    let ok: Bool
    let reason: String?
    let prize: Int?
    let slice: Int?
    let coins: Int
}

struct PurchaseResult: Codable, Sendable {
    let ok: Bool
    let reason: String?
    let orderId: String?
    let spent: Int?
    let itemCount: Int?
    let coins: Int
    let need: Int?
    let bought: [String]?
}

struct ClosetRow: Codable, Sendable {
    let productId: String
    let acquiredAt: String
    let products: Product?
}

struct LedgerEntry: Codable, Identifiable, Sendable {
    let id: Int
    let delta: Int
    let reason: String
    let ref: String?
    let balanceAfter: Int
    let createdAt: String
}

// Outfits
struct OutfitRow: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let createdAt: String?
    let outfitItems: [OutfitItemRow]?
}

struct OutfitItemRow: Codable, Sendable {
    let productId: String
    let slot: String
    let products: Product?
}
