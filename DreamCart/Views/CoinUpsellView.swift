import SwiftUI

/// Where a `CoinUpsellView` was triggered from — drives its copy and the
/// `trigger` analytics prop. `insufficientCoins` is user-initiated (they hit a
/// wall trying to spend) and always allowed to show; other cases are
/// proactive nudges the caller should gate through `UpsellCoordinator` first.
enum UpsellTrigger: String {
    case insufficientCoins = "insufficient_coins"
    case postSpinLowBalance = "post_spin_low_balance"
}

/// A compact, purchase-first sheet for coin-pack upsell moments. Distinct
/// from the full `CoinShopView` browse-all list: this is a single hero pack
/// (the catalog's "POPULAR" one) with a one-tap buy, meant to convert a
/// dopamine moment without making the user scroll a price list.
///
/// Falls back to linking into the full `CoinShopView` when `HAS_REVENUECAT`
/// isn't compiled in (e.g. a build without the SPM dependency configured),
/// rather than showing a purchase button that can't actually charge anyone.
struct CoinUpsellView: View {
    let trigger: UpsellTrigger

    @Environment(ShopStore.self) private var shop
    @Environment(StoreController.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var buying = false
    @State private var purchaseCompleted = false
    @State private var reward: Int? = nil
    @State private var buyTask: Task<Void, Never>? = nil
    @State private var staleCheck: Task<Void, Never>? = nil
    @State private var showFullShop = false

    /// Mirrors CoinShopView's grace window for recovering a purchase left
    /// stuck by a dismissed StoreKit sheet (see that view's doc comment).
    private let graceSeconds: Double = 2.5

    private var pack: CoinPack { CoinPack.recommended }

    private var revenueCatEnabled: Bool {
        #if HAS_REVENUECAT
        true
        #else
        false
        #endif
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                packCard
                PurchaseRecoveryStatus(plus: false)
                if let error = store.lastError {
                    Text(error)
                        .font(.dcCaption)
                        .foregroundStyle(Theme.pink)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
                CandyButton(title: buyTitle, systemImage: "bolt.fill", enabled: !buying && shop.purchaseRecovery.pendingCoins == nil) {
                    buyTask?.cancel()
                    buyTask = Task { await buy() }
                }
                Button("Not now") { dismiss() }
                    .font(.dcLabel)
                    .foregroundStyle(Theme.subtle(scheme))
            }
            .padding(24)
            .background(Theme.bg(scheme))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
        .onAppear {
            store.lastError = nil
            Analytics.track("upsell_shown", ["trigger": trigger.rawValue, "product_id": pack.productId])
            store.trackPaywallImpression(id: "dreamcart_upsell_\(trigger.rawValue)")
        }
        .onChange(of: shop.purchaseRecovery.lastDeliveredCoins) { _, confirmed in
            guard let delivery = confirmed else { return }
            purchaseCompleted = true
            Analytics.track("upsell_purchase_completed",
                            ["trigger": trigger.rawValue, "product_id": delivery.productId, "coins_granted": delivery.coins])
            withAnimation { reward = delivery.coins }
        }
        .onDisappear {
            staleCheck?.cancel()
            staleCheck = nil
            buyTask?.cancel()
            buyTask = nil
            buying = false
            store.isPurchasing = false
            if !purchaseCompleted {
                Analytics.track("upsell_dismissed", ["trigger": trigger.rawValue])
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            staleCheck?.cancel()
            staleCheck = nil
            guard newPhase == .active, buying else { return }
            staleCheck = Task { await recoverIfStale() }
        }
        .overlay {
            if let r = reward {
                RewardOverlay(title: "Coins added", amount: r, subtitle: "Now go get it.") {
                    withAnimation { reward = nil }
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showFullShop) { CoinShopView() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.dcIconHero)
                .foregroundStyle(Theme.goldGradient)
            Text(headline)
                .font(.dcHero)
                .foregroundStyle(Theme.ink(scheme))
                .multilineTextAlignment(.center)
            Text(subheadline)
                .font(.dcBodyText)
                .foregroundStyle(Theme.subtle(scheme))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var headline: String {
        switch trigger {
        case .insufficientCoins: return "Almost there"
        case .postSpinLowBalance: return "Keep it going"
        }
    }

    private var subheadline: String {
        switch trigger {
        case .insufficientCoins: return "Grab more coins and finish checking out."
        case .postSpinLowBalance: return "Top up your wallet so you're ready for the next drop."
        }
    }

    private var packCard: some View {
        VStack(spacing: 14) {
            Text("MOST POPULAR")
                .font(.dcBadge)
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Theme.pink, in: Capsule())
            ZStack {
                Circle().fill(Theme.goldGradient).frame(width: 72, height: 72)
                Image(systemName: "handbag.fill").font(.dcIconL).foregroundStyle(.white)
            }
            VStack(spacing: 4) {
                Text(pack.title).font(.dcTitle).foregroundStyle(Theme.ink(scheme))
                HStack(spacing: 6) {
                    CoinIcon(size: 18)
                    Text("\(Format.coins(pack.coins)) coins")
                        .font(.dcCard)
                        .foregroundStyle(Theme.ink(scheme))
                }
                Text(pack.blurb)
                    .font(.dcSub)
                    .foregroundStyle(Theme.subtle(scheme))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle(scheme)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(Theme.gold, lineWidth: 2)
        )
    }

    private var buyTitle: String {
        guard revenueCatEnabled else { return "See coin packs" }
        return buying ? "Purchasing…" : "Get for \(store.price(for: pack))"
    }

    private func buy() async {
        guard revenueCatEnabled else {
            showFullShop = true
            return
        }
        buying = true
        store.lastError = nil
        Analytics.track("upsell_purchase_started", ["trigger": trigger.rawValue, "product_id": pack.productId])
        defer {
            buying = false
            buyTask = nil
        }
        guard let accountId = shop.purchaseRecovery.accountId else { return }
        do {
            let afterLedgerId = try await shop.prepareCoinPurchase()
            let ok = await store.purchase(pack)
            guard ok else { return }
            shop.purchaseRecovery.beginCoins(
                PendingCoinDelivery(productId: pack.productId, coins: pack.coins, afterLedgerId: afterLedgerId),
                accountId: accountId)
            await shop.reconcilePurchases()
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    /// See `CoinShopView.recoverIfStale` — same failure mode (a dismissed
    /// StoreKit sheet can leave the purchase awaiting forever), same fix.
    private func recoverIfStale() async {
        try? await Task.sleep(for: .seconds(graceSeconds))
        guard !Task.isCancelled, buying, shop.purchaseRecovery.pendingCoins == nil, store.isPurchasing else { return }

        buyTask?.cancel()
        buyTask = nil
        buying = false
        store.isPurchasing = false
        store.lastError = "Purchase didn't complete. You weren't charged."

        let before = shop.coins
        await shop.reconcilePurchases()
        let gained = shop.coins - before
        if gained > 0 {
            store.lastError = nil
            purchaseCompleted = true
            withAnimation { reward = gained }
        }
    }
}
