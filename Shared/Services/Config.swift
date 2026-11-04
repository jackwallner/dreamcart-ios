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

// DreamCart+ — the weekly membership. The server already knows what it grants:
// `claim_daily` doubles the grant and `spin` drops its once-a-day limit when
// `profiles.is_plus` is set, and the RevenueCat webhook flips that flag. What
// was missing was a product to sell, which is what this is.
//
// Weekly at $0.99 on purpose. This is an app for people who like buying things
// without spending money; a yearly commitment is the wrong ask, and a three-day
// trial gets the coin economy doubled while the novelty is still fresh.
enum PlusPlan {
    static let productId = "com.jackwallner.shop.plus.weekly"
    static let name = "DreamCart+"
    static let trialDays = 3
    /// Shown only until StoreKit answers. Never used in a purchase.
    static let fallbackPrice = "$0.99"
    /// Period name for the fleet-wide conversion record. Every app writes its
    /// plan as a bare period (weekly, monthly, yearly, lifetime), never as a
    /// product id, so one query reads the whole portfolio.
    static let conversionPlan = "weekly"
}

// The coin-pack catalog. Product ids match ASC / RevenueCat / the webhook map.
struct CoinPack: Identifiable, Hashable, Sendable {
    let productId: String
    let coins: Int
    let title: String
    let blurb: String
    let badge: Badge?

    var id: String { productId }

    enum Badge: Hashable, Sendable {
        case popular, bestValue

        var label: String {
            switch self {
            case .popular: return String(localized: "POPULAR")
            case .bestValue: return String(localized: "BEST VALUE")
            }
        }
    }

    static let all: [CoinPack] = [
        .init(productId: "com.jackwallner.shop.coins.pocket", coins: 1000,
              title: String(localized: "Pocket"), blurb: String(localized: "A little treat"), badge: nil),
        .init(productId: "com.jackwallner.shop.coins.bag", coins: 3200,
              title: String(localized: "Bag"), blurb: String(localized: "One full look"), badge: .popular),
        .init(productId: "com.jackwallner.shop.coins.haul", coins: 8500,
              title: String(localized: "Haul"), blurb: String(localized: "A whole wardrobe"), badge: nil),
        .init(productId: "com.jackwallner.shop.coins.spree", coins: 20000,
              title: String(localized: "Spree"), blurb: String(localized: "Go all out"), badge: .bestValue),
        .init(productId: "com.jackwallner.shop.coins.vault", coins: 60000,
              title: String(localized: "Vault"), blurb: String(localized: "Never run dry"), badge: nil),
    ]

    /// The single pack showcased in upsell moments and the onboarding coin
    /// offer — reuses the catalog's own "POPULAR" concept rather than
    /// hardcoding a product id, so retuning the catalog automatically retunes
    /// what gets promoted. Falls back to the middle pack if nothing is
    /// tagged POPULAR.
    static var recommended: CoinPack {
        all.first { $0.badge == .popular } ?? all[all.count / 2]
    }
}
