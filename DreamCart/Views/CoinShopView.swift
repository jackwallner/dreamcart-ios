import SwiftUI

struct CoinShopView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(StoreController.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var buying: String? = nil
    @State private var reward: Int? = nil
    @State private var buyTask: Task<Void, Never>? = nil
    @State private var staleCheck: Task<Void, Never>? = nil

    /// How long a purchase gets to finish on its own after we come back to the
    /// foreground before we treat its spinner as stale.
    private let graceSeconds: Double = 2.5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    balanceHeader
                    PurchaseRecoveryStatus(plus: false)
                    if let error = store.lastError {
                        Text(error)
                            .font(.dcSub)
                            .foregroundStyle(Theme.pink)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(CoinPack.all) { pack in
                        packCard(pack)
                    }
                    footer
                }
                .padding(16)
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Get Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .onAppear {
            Analytics.track("coin_shop_viewed")
            store.trackPaywallImpression(id: "dreamcart_coin_shop")
        }
        .overlay {
            if let r = reward {
                RewardOverlay(title: "Coins added", amount: r,
                              subtitle: "Go build something you love.") {
                    withAnimation { reward = nil }
                }
            }
        }
        .onChange(of: shop.purchaseRecovery.lastDeliveredCoins) { _, confirmed in
            guard let delivery = confirmed else { return }
            Analytics.track("coin_pack_purchase_completed", ["product_id": delivery.productId, "coins_granted": delivery.coins])
            withAnimation { reward = delivery.coins }
        }
        .onDisappear {
            staleCheck?.cancel()
            staleCheck = nil
            buyTask?.cancel()
            buyTask = nil
            buying = nil
            store.isPurchasing = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Leaving .active (or a second .active while one is pending) aborts
            // any in-flight staleness check: the user is back inside StoreKit's
            // sheet, so the purchase is not stale.
            staleCheck?.cancel()
            staleCheck = nil
            guard newPhase == .active, buying != nil else { return }
            staleCheck = Task { await recoverIfStale() }
        }
    }

    private var balanceHeader: some View {
        VStack(spacing: 6) {
            Text("Your balance")
                .font(.dcSub)
                .foregroundStyle(.white.opacity(0.85))
            CoinLabel(amount: shop.coins, size: 30)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.corner))
    }

    private func packCard(_ pack: CoinPack) -> some View {
        Button {
            buyTask?.cancel()
            buyTask = Task { await buy(pack) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.goldGradient).frame(width: 58, height: 58)
                    Image(systemName: coinIcon(pack))
                        .font(.dcIconL).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(pack.title)
                            .font(.dcCard)
                            .foregroundStyle(Theme.ink(scheme))
                        if let badge = pack.badge {
                            Text(badge)
                                .font(.dcBadge)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.pink, in: Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        CoinIcon(size: 14)
                        Text("\(Format.coins(pack.coins)) coins")
                            .font(.dcBody)
                            .foregroundStyle(Theme.ink(scheme))
                    }
                    Text(pack.blurb)
                        .font(.dcSub)
                        .foregroundStyle(Theme.subtle(scheme))
                }
                Spacer()
                if buying == pack.productId {
                    ProgressView()
                } else {
                    Text(store.price(for: pack))
                        .font(.dcPrice)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.candy, in: Capsule())
                }
            }
            .padding(14)
            .cardStyle(scheme)
        }
        .buttonStyle(PressableStyle())
        .disabled(buying != nil || shop.purchaseRecovery.pendingCoins != nil)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Coins are for use inside DreamCart only and have no cash value. All items and delivery are virtual.")
                .font(.dcCaption)
                .foregroundStyle(Theme.subtle(scheme))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private func coinIcon(_ pack: CoinPack) -> String {
        switch pack.title {
        case "Pocket": return "bag.fill"
        case "Bag": return "handbag.fill"
        case "Haul": return "cart.fill"
        case "Spree": return "sparkles"
        default: return "crown.fill"
        }
    }

    private func buy(_ pack: CoinPack) async {
        buying = pack.productId
        store.lastError = nil
        Analytics.track("coin_pack_purchase_started", ["product_id": pack.productId, "coins": pack.coins])
        defer {
            buying = nil
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

    /// Dismissing StoreKit's system sheet (e.g. cancelling Apple Account
    /// sign-in) can leave `Purchases.shared.purchase` suspended forever: it
    /// neither returns nor throws, so neither `buy`'s defer nor
    /// StoreController's own defer ever runs. `store.isPurchasing` is stuck
    /// true in exactly that case, so it can't be used to detect it. Instead we
    /// give the purchase a grace period after we're back in the foreground and,
    /// if the spinner is still up, cancel the task holding the suspended await
    /// and reset the state by hand.
    private func recoverIfStale() async {
        try? await Task.sleep(for: .seconds(graceSeconds))
        // Cancelled means the phase left .active again; nil `buying` means the
        // purchase finished on its own. Either way there's nothing stale.
        guard !Task.isCancelled, buying != nil, shop.purchaseRecovery.pendingCoins == nil, store.isPurchasing else { return }

        buyTask?.cancel()   // unwinds the await if the SDK honors cancellation
        buyTask = nil
        buying = nil
        // The SDK's continuation may never resume even on cancel, so
        // StoreController's `defer { isPurchasing = false }` can't be trusted.
        store.isPurchasing = false
        store.lastError = "Purchase didn't complete. You weren't charged."

        // Safety net for the false-positive case: if the purchase actually did
        // settle, the server grants the coins and reconcile heals it here.
        let before = shop.coins
        await shop.reconcilePurchases()
        let gained = shop.coins - before
        if gained > 0 {
            store.lastError = nil
            withAnimation { reward = gained }
        }
    }
}
