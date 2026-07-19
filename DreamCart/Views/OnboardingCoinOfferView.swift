import SwiftUI

/// The final onboarding step for a brand-new user, shown exactly once right
/// after their first sign-in (see `RootView`, gated on
/// `AuthController.justCompletedOnboarding` so returning/existing users never
/// see it again). Presents the catalog's "most popular" coin pack with the
/// purchase CTA anchored in the same bottom thumb zone `WelcomeView` uses for
/// "Next" / "Get started", so onboarding's muscle memory lands on it.
///
/// "Not now" is always enabled and always available — onboarding must
/// complete whether or not the user buys anything (App Review 3.1.1 requires
/// a clear way to decline an optional purchase).
struct OnboardingCoinOfferView: View {
    /// Called once the user is done here (bought or skipped) so `RootView`
    /// can move on to the tab bar.
    let onContinue: () -> Void

    @Environment(ShopStore.self) private var shop
    @Environment(StoreController.self) private var store
    @Environment(\.colorScheme) private var scheme

    @State private var buying = false
    @State private var reward: Int? = nil
    @State private var buyTask: Task<Void, Never>? = nil

    private var pack: CoinPack { CoinPack.recommended }

    private var revenueCatEnabled: Bool {
        #if HAS_REVENUECAT
        true
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 24)
                    ZStack {
                        Circle().fill(Theme.gold.opacity(0.15)).frame(width: 150, height: 150)
                        Image(systemName: "gift.fill")
                            .font(.dcIconHero)
                            .foregroundStyle(Theme.goldGradient)
                    }
                    VStack(spacing: 10) {
                        Text("Start with a full wallet")
                            .font(.dcHero)
                            .foregroundStyle(Theme.ink(scheme))
                            .multilineTextAlignment(.center)
                        Text("Grab our most popular coin pack now and skip straight to the good stuff.")
                            .font(.dcBodyText)
                            .foregroundStyle(Theme.subtle(scheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    packCard
                    if let error = store.lastError {
                        Text(error)
                            .font(.dcCaption)
                            .foregroundStyle(Theme.pink)
                            .multilineTextAlignment(.center)
                    }
                    Spacer(minLength: 12)
                }
            }

            VStack(spacing: 12) {
                CandyButton(title: buyTitle, systemImage: "bolt.fill", enabled: !buying) {
                    buyTask?.cancel()
                    buyTask = Task { await buy() }
                }
                // Always enabled, even mid-purchase: a stuck StoreKit sheet
                // must never be able to trap someone inside onboarding.
                Button("Not now") {
                    Analytics.track("onboarding_pack_skipped")
                    onContinue()
                }
                .font(.dcLabel)
                .foregroundStyle(Theme.subtle(scheme))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(Theme.bg(scheme))
        .onAppear {
            Analytics.track("onboarding_pack_shown", ["product_id": pack.productId])
        }
        .onDisappear { buyTask?.cancel() }
        .overlay {
            if let r = reward {
                RewardOverlay(title: "Coins added", amount: r, subtitle: "Enjoy the shop.") {
                    withAnimation { reward = nil }
                    onContinue()
                }
            }
        }
    }

    private var buyTitle: String {
        guard revenueCatEnabled else { return "See coin packs" }
        return buying ? "Purchasing…" : "Get \(Format.coins(pack.coins)) coins for \(store.price(for: pack))"
    }

    private var packCard: some View {
        VStack(spacing: 12) {
            Text("MOST POPULAR")
                .font(.dcBadge)
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Theme.pink, in: Capsule())
            HStack(spacing: 8) {
                CoinIcon(size: 22)
                Text("\(Format.coins(pack.coins)) coins")
                    .font(.dcTitle)
                    .foregroundStyle(Theme.ink(scheme))
            }
            Text(pack.blurb)
                .font(.dcSub)
                .foregroundStyle(Theme.subtle(scheme))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle(scheme)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(Theme.gold, lineWidth: 2)
        )
        .padding(.horizontal, 28)
    }

    private func buy() async {
        guard revenueCatEnabled else {
            // No IAP compiled into this build — nothing to purchase here, so
            // just move on; the coin shop is still reachable from inside the app.
            onContinue()
            return
        }
        buying = true
        store.lastError = nil
        Analytics.track("coin_pack_purchase_started",
                         ["product_id": pack.productId, "coins": pack.coins, "source": "onboarding"])
        defer {
            buying = false
            buyTask = nil
        }
        let before = shop.coins
        let ok = await store.purchase(pack)
        guard !Task.isCancelled else { return }
        if ok {
            await shop.reconcilePurchases()
            let gained = shop.coins - before
            if gained > 0 {
                Analytics.track("onboarding_pack_purchased",
                                 ["product_id": pack.productId, "coins_granted": gained])
                withAnimation { reward = gained }
            }
        }
    }
}
