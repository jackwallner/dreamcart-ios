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
