import Foundation
import SwiftUI

// The central app state: catalog, the signed-in user's economy, cart, closet,
// favorites and outfits. All coin mutations round-trip through server RPCs so
// the client only ever reflects the authoritative balance.
@MainActor
@Observable
final class ShopStore {
    var me: MeSnapshot?
    var brands: [Brand] = []
    var products: [ProductWithBrand] = []
    var closet: [Product] = []
    var outfits: [OutfitRow] = []
    var ledger: [LedgerEntry] = []

    var ownedIds: Set<String> = []
    var favoriteIds: Set<String> = []
    var dismissedRecommendationIds: Set<String> = []
    var acceptedRecommendationIds: Set<String> = []
    var cartIds: [String] = []          // ordered so the cart list is stable

    var isLoading = false
    var loadError: String?

    /// True once the first refreshAll() has finished, successfully or not. RootView
    /// holds the splash until then: signing in flips auth to .signedIn immediately,
    /// so without this the tab bar renders against an empty catalog and the app
    /// looks blank until the network catches up. Set even on failure, so a failed
    /// load lands on the tabs (with the error banner) instead of splashing forever.
    var hasLoadedOnce = false

    private let sb = SupabaseClient.shared

    var coins: Int { me?.coins ?? 0 }
    var brandById: [String: Brand] { Dictionary(brands.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    // MARK: bulk load

    func refreshAll() async {
        isLoading = true
        loadError = nil
        defer {
            isLoading = false
            hasLoadedOnce = true
        }
        do {
            async let m: MeSnapshot = sb.rpc("me")
            async let b: [Brand] = sb.select("brands?select=*&order=sort.asc")
            async let p: [ProductWithBrand] =
                sb.select("products?select=*,brands(*)&is_active=eq.true&order=drop_date.desc,created_at.desc&limit=1000")
            me = try await m
            brands = try await b
            products = try await p
            await loadCloset()
            await loadFavorites()
            await loadRecommendationFeedback()
        } catch {
            loadError = (error as? SBError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refreshMe() async {
        if let m: MeSnapshot = try? await sb.rpc("me") { me = m }
    }

    func loadCloset() async {
        struct Row: Decodable { let products: Product? }
        if let rows: [Row] = try? await sb.select(
            "closet_items?select=products(*)&order=acquired_at.desc") {
            closet = rows.compactMap { $0.products }
            ownedIds = Set(closet.map { $0.id })
        }
    }

    func loadFavorites() async {
        struct Row: Decodable { let productId: String }
        if let rows: [Row] = try? await sb.select("favorites?select=product_id") {
            favoriteIds = Set(rows.map { $0.productId })
        }
    }

    func loadLedger() async {
        if let rows: [LedgerEntry] = try? await sb.select(
            "coin_ledger?select=*&order=created_at.desc&limit=60") {
            ledger = rows
        }
    }

    // MARK: rewards

    @discardableResult
    func claimDaily() async -> DailyResult? {
        guard let r: DailyResult = try? await sb.rpc("claim_daily") else { return nil }
        await refreshMe()
        return r
    }

    @discardableResult
    func spin() async -> SpinResult? {
        guard let r: SpinResult = try? await sb.rpc("spin") else { return nil }
        await refreshMe()
        return r
    }

    // MARK: recommendations

    private enum RecommendationAction: String {
        case dismissed
        case addedToCart = "added_to_cart"
    }

    func loadRecommendationFeedback() async {
        struct Row: Decodable {
            let productId: String
            let action: String
        }
        guard let rows: [Row] = try? await sb.select(
            "recommendation_feedback?select=product_id,action"
        ) else { return }
        dismissedRecommendationIds = Set(rows.filter { $0.action == RecommendationAction.dismissed.rawValue }.map(\.productId))
        acceptedRecommendationIds = Set(rows.filter { $0.action == RecommendationAction.addedToCart.rawValue }.map(\.productId))
    }

    var forYouProducts: [ProductWithBrand] {
        rankedRecommendations(limit: 30)
    }

    func resetRecommendationDismissals() {
        dismissedRecommendationIds.removeAll()
    }

    func dismissRecommendation(_ id: String) {
        dismissedRecommendationIds.insert(id)
        Haptics.rigid()
        persistRecommendation(id, action: .dismissed)
    }

    private func persistRecommendation(_ id: String, action: RecommendationAction) {
        Task {
            struct Feedback: Decodable {
                let productId: String
                let action: String
            }
            let _: Feedback? = try? await sb.rpc(
                "record_recommendation_feedback",
                args: ["p_product_id": id, "p_action": action.rawValue]
            )
        }
    }

    // MARK: cart + checkout

    var cartProducts: [Product] {
        cartIds.compactMap { id in products.first { $0.id == id }.map(Self.plain) }
    }
    var cartTotal: Int { cartProducts.reduce(0) { $0 + $1.price } }
    var canAfford: Bool { cartTotal <= coins }

    func inCart(_ id: String) -> Bool { cartIds.contains(id) }

    @discardableResult
    func addToCart(_ id: String, recommendation: Bool = false) -> Bool {
        guard !cartIds.contains(id) else { return false }
        cartIds.append(id)
        Haptics.soft()
        if recommendation {
            acceptedRecommendationIds.insert(id)
            persistRecommendation(id, action: .addedToCart)
        }
        return true
    }

    func toggleCart(_ id: String) {
        if let i = cartIds.firstIndex(of: id) { cartIds.remove(at: i); Haptics.tap() }
        else { _ = addToCart(id) }
    }
    func removeFromCart(_ id: String) { cartIds.removeAll { $0 == id } }
    func clearCart() { cartIds.removeAll() }

    @discardableResult
    func checkout() async -> PurchaseResult? {
        let ids = cartIds
        guard !ids.isEmpty else { return nil }
        guard let r: PurchaseResult = try? await sb.rpc("purchase_cart", args: ["p_product_ids": ids])
        else { return nil }
        if r.ok {
            ownedIds.formUnion(r.bought ?? [])
            clearCart()
            await loadCloset()
            await refreshMe()
        }
        return r
    }

    // MARK: favorites

    func isFavorite(_ id: String) -> Bool { favoriteIds.contains(id) }

    func toggleFavorite(_ id: String) async {
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
            _ = try? await sb.write("favorites?product_id=eq.\(id)", method: "DELETE", body: nil)
        } else {
            favoriteIds.insert(id)
            Haptics.tap()
            guard let uid = await sb.currentUserId else { return }
            _ = try? await sb.write("favorites", method: "POST",
                                    body: ["user_id": uid, "product_id": id])
        }
    }

    // MARK: outfits

    func loadOutfits() async {
        if let rows: [OutfitRow] = try? await sb.select(
            "outfits?select=*,outfit_items(slot,product_id,products(*))&order=updated_at.desc") {
            outfits = rows
        }
    }

    /// Save a look: slot → productId. Creates the outfit then its items.
    @discardableResult
    func saveOutfit(name: String, items: [String: String]) async -> Bool {
        guard let uid = await sb.currentUserId else { return false }
        struct Created: Decodable { let id: String }
        guard
            let data = try? await sb.write("outfits", method: "POST",
                                           body: ["user_id": uid, "name": name]),
            let created = try? SupabaseClient.decoder.decode([Created].self, from: data),
            let outfit = created.first
        else { return false }
        let rows = items.map { ["outfit_id": outfit.id, "slot": $0.key, "product_id": $0.value] }
        _ = try? await sb.write("outfit_items", method: "POST", body: rows)
        await loadOutfits()
        Haptics.success()
        return true
    }

    func deleteOutfit(_ id: String) async {
        _ = try? await sb.write("outfits?id=eq.\(id)", method: "DELETE", body: nil)
        outfits.removeAll { $0.id == id }
    }

    // MARK: purchase reconciliation (RevenueCat → coins)

    /// Ask the server to grant coins for any store purchase not yet credited.
    func reconcilePurchases() async {
        struct RedeemResult: Decodable { let ok: Bool; let coins: Int?; let granted: Int? }
        if let r: RedeemResult = try? await sb.callFunction("redeem"), r.ok {
            await refreshMe()
        }
    }

    // MARK: derived catalog

    var newDropIds: Set<String> {
        let today = Self.todayUTC()
        return Set(products.filter { $0.dropDate == today }.map { $0.id })
    }
    var newDrops: [ProductWithBrand] {
        let sorted = products.sorted { ($0.dropDate ?? "") > ($1.dropDate ?? "") }
        return Array(sorted.prefix(20))
    }
    func products(brandId: String) -> [ProductWithBrand] { products.filter { $0.brandId == brandId } }
    func products(category: String) -> [ProductWithBrand] { products.filter { $0.category == category } }

    func search(_ q: String) -> [ProductWithBrand] {
        let t = q.lowercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return [] }
        return products.filter {
            $0.name.lowercased().contains(t)
            || $0.colorName.lowercased().contains(t)
            || $0.category.lowercased().contains(t)
            || ($0.brands?.name.lowercased().contains(t) ?? false)
            || $0.styleTags.contains { $0.lowercased().contains(t) }
        }
    }

    func complementaryProducts(for product: ProductWithBrand, limit: Int = 6) -> [ProductWithBrand] {
        rankedRecommendations(anchor: product, preferDifferentSlots: true, limit: limit)
    }

    private func rankedRecommendations(anchor: ProductWithBrand? = nil,
                                       preferDifferentSlots: Bool = false,
                                       limit: Int) -> [ProductWithBrand] {
        let positive = products.filter {
            ownedIds.contains($0.id) || favoriteIds.contains($0.id) || acceptedRecommendationIds.contains($0.id)
        }
        let candidates = products.filter {
            $0.id != anchor?.id
                && !ownedIds.contains($0.id)
                && !cartIds.contains($0.id)
                && !dismissedRecommendationIds.contains($0.id)
        }
        let scored = candidates.enumerated().map { index, candidate in
            let score = recommendationScore(candidate, anchor: anchor, positive: positive,
                                            preferDifferentSlots: preferDifferentSlots)
            return (candidate, score, index)
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.2 < $1.2
        }

        var result: [ProductWithBrand] = []
        var slotCounts: [String: Int] = [:]
        var brandCounts: [String: Int] = [:]
        for entry in scored {
            let candidate = entry.0
            let slotCap = preferDifferentSlots ? 1 : 4
            guard slotCounts[candidate.slot, default: 0] < slotCap,
                  brandCounts[candidate.brandId, default: 0] < 5 else { continue }
            result.append(candidate)
            slotCounts[candidate.slot, default: 0] += 1
            brandCounts[candidate.brandId, default: 0] += 1
            if result.count == limit { break }
        }
        return result
    }

    private func recommendationScore(_ candidate: ProductWithBrand,
                                     anchor: ProductWithBrand?,
                                     positive: [ProductWithBrand],
                                     preferDifferentSlots: Bool) -> Int {
        let references = anchor.map { [$0] } ?? positive
        var score = 0
        for reference in references {
            if candidate.brandId == reference.brandId { score += 8 }
            if candidate.category == reference.category { score += 4 }
            if candidate.slot == reference.slot { score += preferDifferentSlots ? -12 : 4 }
            else if preferDifferentSlots { score += 10 }
            score += Set(candidate.styleTags).intersection(reference.styleTags).count * 6
            if candidate.colorName.caseInsensitiveCompare(reference.colorName) == .orderedSame { score += 3 }
        }
        if favoriteIds.contains(candidate.id) { score += 12 }
        if acceptedRecommendationIds.contains(candidate.id) { score += 10 }
        if newDropIds.contains(candidate.id) { score += 2 }
        score += candidate.rarityKind == .legendary ? 2 : candidate.rarityKind == .epic ? 1 : 0
        return score
    }

    /// Today in UTC as "YYYY-MM-DD", matching the DB's `current_date`.
    static func todayUTC() -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func plain(_ p: ProductWithBrand) -> Product {
        Product(id: p.id, brandId: p.brandId, name: p.name, category: p.category, slot: p.slot,
                styleTags: p.styleTags, colorName: p.colorName, price: p.price, rarity: p.rarity,
                description: p.description, imageUrl: p.imageUrl, dropDate: p.dropDate)
    }
}

