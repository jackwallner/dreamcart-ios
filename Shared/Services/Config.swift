import Foundation

// Publishable, client-safe keys. The publishable Supabase key and the RC public
// SDK key are designed to ship in the app binary; nothing secret lives here.
enum Config {
    static let supabaseURL = URL(string: "https://wpjmshibfhdpzvfrjzrv.supabase.co")!
    static let supabasePublishableKey = "sb_publishable_obm-_XQQoXyUjYCm6MLh6w_6nBu1gBu"
    static let revenueCatKey = "appl_ynnjicfEjSzfqrTDJeSKkmGNHgJ"

    static var restURL: URL { supabaseURL.appendingPathComponent("rest/v1") }
    static var authURL: URL { supabaseURL.appendingPathComponent("auth/v1") }
    static var functionsURL: URL { supabaseURL.appendingPathComponent("functions/v1") }
}

// The coin-pack catalog. Product ids match ASC / RevenueCat / the webhook map.
struct CoinPack: Identifiable, Hashable, Sendable {
    let productId: String
    let coins: Int
    let title: String
    let blurb: String
    let badge: String?      // "POPULAR" / "BEST VALUE"

    var id: String { productId }

    static let all: [CoinPack] = [
        .init(productId: "com.jackwallner.shop.coins.pocket", coins: 1000,
              title: "Pocket", blurb: "A little treat", badge: nil),
        .init(productId: "com.jackwallner.shop.coins.bag", coins: 3200,
              title: "Bag", blurb: "One full look", badge: "POPULAR"),
        .init(productId: "com.jackwallner.shop.coins.haul", coins: 8500,
              title: "Haul", blurb: "A whole wardrobe", badge: nil),
        .init(productId: "com.jackwallner.shop.coins.spree", coins: 20000,
              title: "Spree", blurb: "Go all out", badge: "BEST VALUE"),
        .init(productId: "com.jackwallner.shop.coins.vault", coins: 60000,
              title: "Vault", blurb: "Never run dry", badge: nil),
    ]

    /// The single pack showcased in upsell moments and the onboarding coin
    /// offer — reuses the catalog's own "POPULAR" concept rather than
    /// hardcoding a product id, so retuning the catalog automatically retunes
    /// what gets promoted. Falls back to the middle pack if nothing is
    /// tagged POPULAR.
    static var recommended: CoinPack {
        all.first { $0.badge == "POPULAR" } ?? all[all.count / 2]
    }
}
