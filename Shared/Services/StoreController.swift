import Foundation
import SwiftUI
#if HAS_REVENUECAT
import RevenueCat
#endif

// RevenueCat coin-pack purchasing. Coins are credited server-side (redeem /
// webhook), so this controller's job is just: run the purchase, then ask the
// ShopStore to reconcile with the server. Products are fetched by id, so no
// RevenueCat "offering" needs to be configured for purchases to work.
@MainActor
@Observable
final class StoreController {
    var prices: [String: String] = [:]     // productId -> localized price
    var isReady = false
    var isPurchasing = false
    var isRestoring = false
    var lastError: String?

    #if HAS_REVENUECAT
    private var storeProducts: [String: StoreProduct] = [:]
    #endif

    func configure(userId: String?) {
        #if HAS_REVENUECAT
        #if targetEnvironment(simulator)
        return
        #else
        Purchases.logLevel = .error
        if !Purchases.isConfigured {
            let builder = Configuration.Builder(withAPIKey: Config.revenueCatKey)
            if let userId { _ = builder.with(appUserID: userId) }
            Purchases.configure(with: builder.build())
        } else if let userId {
            Purchases.shared.logIn(userId) { _, _, _ in }
        }
        Task { await loadProducts() }
        #endif
        #endif
    }

    func loadProducts() async {
        #if HAS_REVENUECAT
        let ids = CoinPack.all.map(\.productId)
        let products = await Purchases.shared.products(ids)
        for p in products {
            storeProducts[p.productIdentifier] = p
            prices[p.productIdentifier] = p.localizedPriceString
        }
        isReady = !products.isEmpty
        #endif
    }

    func price(for pack: CoinPack) -> String {
        prices[pack.productId] ?? fallbackPrice(pack)
    }

    private func fallbackPrice(_ pack: CoinPack) -> String {
        switch pack.title {
        case "Pocket": return "$1.99"
        case "Bag":    return "$4.99"
        case "Haul":   return "$9.99"
        case "Spree":  return "$19.99"
        default:        return "$49.99"
        }
    }

    /// Returns true if the purchase completed (coins credited by the caller's
    /// reconcile step).
    func purchase(_ pack: CoinPack) async -> Bool {
        #if HAS_REVENUECAT
        #if targetEnvironment(simulator)
        lastError = "Coin packs are available on a device or TestFlight build."
        return false
        #else
        guard let product = storeProducts[pack.productId] else {
            await loadProducts()
            guard let retry = storeProducts[pack.productId] else {
                lastError = "This pack isn't available right now."
                return false
            }
            return await run(retry)
        }
        return await run(product)
        #endif
        #else
        return false
        #endif
    }

    #if HAS_REVENUECAT
    private func run(_ product: StoreProduct) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            if result.userCancelled { return false }
            Haptics.celebrate()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    #endif

    func restore() async {
        #if HAS_REVENUECAT
        #if targetEnvironment(simulator)
        lastError = "Restore Purchases is available on a device or TestFlight build."
        return
        #else
        guard !isRestoring else { return }
        isRestoring = true
        lastError = nil
        defer { isRestoring = false }
        do {
            _ = try await Purchases.shared.restorePurchases()
        } catch {
            lastError = error.localizedDescription
        }
        #endif
        #endif
    }
}
