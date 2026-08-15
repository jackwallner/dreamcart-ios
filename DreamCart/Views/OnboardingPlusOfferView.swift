import SwiftUI

/// The final onboarding step for a brand-new user: the DreamCart+ trial.
///
/// This replaced the one-shot coin-pack offer that used to sit here. The pack
/// asked someone who has just met the app to buy currency for a game they have
/// not played yet, and it converted nobody. The membership asks a smaller
/// question at a better moment, and it is the one purchase that makes the
/// dopamine loop itself better: `claim_daily` doubles its grant for members and
/// `spin` drops its once-a-day limit, both server-side off `profiles.is_plus`.
///
/// Zero-shift rule: the primary button occupies exactly the same slot and
/// geometry as `WelcomeView`'s Next / Get started, so the thumb that swiped
/// through onboarding lands on it without the layout moving. The soft exit
/// below it is always enabled, even mid-purchase, so a stuck StoreKit sheet can
/// never trap anyone inside onboarding (App Review 3.1.1).
struct OnboardingPlusOfferView: View {
    /// Called once the user is done here, bought or not, so `RootView` can move
    /// on to the tab bar.
    let onContinue: () -> Void

    @Environment(ShopStore.self) private var shop
    @Environment(StoreController.self) private var store
    @Environment(\.colorScheme) private var scheme

    @State private var buying = false
    @State private var restoring = false
    @State private var didSubscribe = false
    @State private var buyTask: Task<Void, Never>? = nil

    private var revenueCatEnabled: Bool {
        #if HAS_REVENUECAT
        true
        #else
        false
        #endif
    }

    /// Height the scroll content should at least fill so the pitch centres.
    @State private var geoHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Centred, not top-pinned. The pitch is short enough to underfill a
            // tall phone, and pinning it to the top left a third of the screen
            // empty above the CTA. `minHeight` keeps taller content (a long
            // localized disclosure, large text sizes) scrolling normally.
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 20)
                    crown
                    VStack(spacing: 10) {
                        Text(headline)
                            .font(.dcHero)
                            .foregroundStyle(Theme.ink(scheme))
                            .multilineTextAlignment(.center)
                        Text("Every day counts double, and the wheel never stops.")
                            .font(.dcBodyText)
                            .foregroundStyle(Theme.subtle(scheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    perks
                    if let error = store.lastError {
                        Text(error)
                            .font(.dcCaption)
                            .foregroundStyle(Theme.pink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, minHeight: geoHeight)
            }

            VStack(spacing: 12) {
                CandyButton(title: ctaTitle, systemImage: "sparkles", enabled: !buying) {
                    buyTask?.cancel()
                    buyTask = Task { await subscribe() }
                }
                Text(disclosure)
                    .font(.dcCaption)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    Button("Not now") {
                        Analytics.track("onboarding_plus_skipped")
                        onContinue()
                    }
                    Button(restoring ? "Restoring…" : "Restore") { restore() }
                        .disabled(restoring)
                    Link("Terms", destination: PlusLinks.terms)
                    Link("Privacy", destination: PlusLinks.privacy)
                }
                .font(.dcLabel)
                .foregroundStyle(Theme.subtle(scheme))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(
            GeometryReader { geo in
                Theme.bg(scheme)
                    .onAppear { geoHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in geoHeight = h }
            }
        )
        .task {
            await store.loadProducts()
            await store.refreshPlusTrialEligibility()
        }
        .onAppear {
            Analytics.track("onboarding_plus_shown", ["product_id": PlusPlan.productId])
            store.trackPaywallImpression(id: "dreamcart_onboarding_plus", oncePerSession: true)
        }
        .onDisappear { buyTask?.cancel() }
        .overlay {
            if didSubscribe {
                RewardOverlay(title: "\(PlusPlan.name) unlocked",
                              amount: nil,
                              subtitle: "Your daily coins just doubled.") {
                    onContinue()
                }
            }
        }
    }

    // MARK: - Pieces

    private var crown: some View {
        ZStack {
            Circle().fill(Theme.gold.opacity(0.15)).frame(width: 150, height: 150)
            Image(systemName: "crown.fill")
                .font(.dcIconHero)
                .foregroundStyle(Theme.goldGradient)
        }
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 14) {
            perk("bolt.fill", "Double coins every single day")
            perk("arrow.triangle.2.circlepath", "Spin the wheel as often as you like")
            perk("bag.fill", "Check out faster, and more often")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cardStyle(scheme)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(Theme.gold, lineWidth: 2)
        )
        .padding(.horizontal, 28)
    }

    private func perk(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.dcSub)
                .foregroundStyle(Theme.goldGradient)
                .frame(width: 24)
            Text(text)
                .font(.dcSub)
                .foregroundStyle(Theme.ink(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Copy

    private var headline: String {
        store.plusTrialEligible ? "Try \(PlusPlan.name) free" : "Get \(PlusPlan.name)"
    }

    private var ctaTitle: String {
        guard revenueCatEnabled else { return "Continue" }
        if buying { return "Starting…" }
        return store.plusTrialEligible
            ? "Start \(PlusPlan.trialDays)-day free trial"
            : "Get \(PlusPlan.name)"
    }

    /// One concise line, matching the approved fleet pattern: trial length,
    /// price, that it renews, how to cancel. Drops the amount rather than
    /// inventing one when StoreKit has not answered yet.
    private var disclosure: String {
        guard let price = store.plusPrice else {
            return store.plusTrialEligible
                ? "\(PlusPlan.trialDays) days free, then a weekly charge. Auto-renews until canceled."
                : "Billed weekly. Auto-renews until canceled."
        }
        return store.plusTrialEligible
            ? "\(PlusPlan.trialDays) days free, then \(price) per week. Auto-renews until canceled. Cancel anytime in Settings."
            : "\(price) per week. Auto-renews until canceled. Cancel anytime in Settings."
    }

    // MARK: - Actions

    private func subscribe() async {
        guard revenueCatEnabled else {
            onContinue()
            return
        }
        buying = true
        store.lastError = nil
        Analytics.track("plus_purchase_started",
                        ["product_id": PlusPlan.productId, "source": "onboarding"])
        defer {
            buying = false
            buyTask = nil
        }
        let ok = await store.purchasePlus()
        guard !Task.isCancelled, ok else { return }
        // `is_plus` is set by the RevenueCat webhook, so the profile is the
        // source of truth, not anything the device decided.
        await shop.refreshMe()
        Analytics.track("plus_purchased", ["product_id": PlusPlan.productId, "source": "onboarding"])
        withAnimation { didSubscribe = true }
    }

    private func restore() {
        restoring = true
        Task {
            defer { restoring = false }
            let ok = await store.restorePlus()
            await shop.refreshMe()
            if ok {
                withAnimation { didSubscribe = true }
            } else {
                store.lastError = "No previous \(PlusPlan.name) membership on this Apple Account."
            }
        }
    }
}

enum PlusLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://jackwallner.github.io/dreamcart/privacy-policy.html")!
}
