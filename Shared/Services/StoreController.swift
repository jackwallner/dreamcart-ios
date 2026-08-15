import Foundation
import StoreKit
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
    var lastError: String?

    #if HAS_REVENUECAT
    private var storeProducts: [String: StoreProduct] = [:]
    #endif
    private var paywallImpressionsThisSession: Set<String> = []

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
        // `Purchases.shared` traps when the SDK was never configured, which is
        // every simulator run (configure() returns early there) and any device
        // where the key is a placeholder. This used to be called only from
        // configure(), so the trap was unreachable; it is a public entry point
        // now, so it has to be safe on its own.
        guard Purchases.isConfigured else {
            await loadPlusPriceFromStoreKit()
            return
        }
        let ids = CoinPack.all.map(\.productId) + [PlusPlan.productId]
        let products = await Purchases.shared.products(ids)
        for p in products {
            storeProducts[p.productIdentifier] = p
            prices[p.productIdentifier] = p.localizedPriceString
        }
        isReady = products.contains { $0.productIdentifier != PlusPlan.productId }
        #endif
    }

    /// Feeds RevenueCat's `paywall_encounter_v3`. Every coin surface here is a
    /// custom one, so without this call nothing in this app is visible between
    /// "installed" and "paid", and the shop's real problem stays unknowable.
    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        #if HAS_REVENUECAT
        guard Purchases.isConfigured else { return }
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
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

    // MARK: - DreamCart+

    /// Reads the membership price straight from StoreKit when RevenueCat is not
    /// configured. That is every simulator run, which is also the only place the
    /// App Review screenshot can be captured, and a paywall screenshot without a
    /// price is one App Review rejects. Under a StoreKit Testing configuration
    /// this returns the real $0.99 and the real 3-day introductory offer; with no
    /// configuration it finds nothing and the fallback copy stands.
    private func loadPlusPriceFromStoreKit() async {
        // `Product` on its own resolves to DreamCart's own catalog model, so
        // this has to name StoreKit's explicitly.
        guard let product = try? await StoreKit.Product.products(for: [PlusPlan.productId]).first else {
            return
        }
        prices[PlusPlan.productId] = product.displayPrice
        if let intro = product.subscription?.introductoryOffer,
           intro.paymentMode == StoreKit.Product.SubscriptionOffer.PaymentMode.freeTrial {
            plusTrialEligible = true
        }
    }

    /// The billed weekly amount, localized. Nil until StoreKit answers — a
    /// price we did not get from the store is worse than no price at all, so
    /// callers show the loading state rather than inventing one.
    var plusPrice: String? { prices[PlusPlan.productId] }

    /// True only when this Apple Account can still take the introductory free
    /// trial. A returning subscriber must never be promised a free trial they
    /// have already consumed (App Review 3.1.2).
    private(set) var plusTrialEligible = false

    func refreshPlusTrialEligibility() async {
        #if HAS_REVENUECAT
        guard Purchases.isConfigured else { return }  // StoreKit path already answered
        guard
              let product = storeProducts[PlusPlan.productId],
              product.introductoryDiscount != nil else {
            plusTrialEligible = false
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: [PlusPlan.productId]
        )
        plusTrialEligible = result[PlusPlan.productId]?.status == .eligible
        #endif
    }

    /// Buys the weekly membership. `is_plus` is set server-side by the
    /// RevenueCat webhook, so the caller refreshes the profile afterwards
    /// rather than trusting anything decided on the device.
    func purchasePlus() async -> Bool {
        #if HAS_REVENUECAT
        guard let product = storeProducts[PlusPlan.productId] else {
            await loadProducts()
            guard let retry = storeProducts[PlusPlan.productId] else {
                lastError = "\(PlusPlan.name) isn't available right now."
                return false
            }
            return await run(retry)
        }
        return await run(product)
        #else
        return false
        #endif
    }

    /// Subscriptions, unlike the coin packs, need a restore path (App Review
    /// 3.1.1): a member reinstalling must be able to get their membership back
    /// without paying again.
    func restorePlus() async -> Bool {
        #if HAS_REVENUECAT
        guard Purchases.isConfigured else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            return info.activeSubscriptions.contains(PlusPlan.productId)
        } catch {
            lastError = error.localizedDescription
            return false
        }
        #else
        return false
        #endif
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
        guard Purchases.isConfigured else {
            lastError = "Purchases aren't available in this build."
            return false
        }
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

}

// Deliberately no StoreKit restore path. Every product here is a consumable
// coin pack. The current unspent balance belongs to the signed-in DreamCart
// account, while `ShopStore.reconcilePurchases()` retries any incomplete
// delivery idempotently by store transaction id.
