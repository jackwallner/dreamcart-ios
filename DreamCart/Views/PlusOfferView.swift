import SwiftUI

/// Where this offer is being shown from. The pitch is identical either way;
/// only the exit affordance and the analytics/paywall id differ.
enum PlusOfferPresentation {
    /// The final onboarding step for a brand-new user. Full screen, soft exit
    /// reading "Not now", and `onDone` advances RootView to the tab bar.
    case onboarding
    /// A sheet raised from the You tab. Soft exit reads "Maybe later" and
    /// `onDone` dismisses.
    case sheet
}

/// The DreamCart+ trial pitch.
///
/// This replaced the one-shot coin-pack offer in onboarding. The pack asked
/// someone who has just met the app to buy currency for a game they have not
/// played yet, and it converted nobody. The membership asks a smaller question
/// at a better moment, and it is the one purchase that makes the dopamine loop
/// itself better: `claim_daily` doubles its grant for members and `spin` drops
/// its once-a-day limit, both server-side off `profiles.is_plus`.
///
/// It is reachable from two places on purpose. Onboarding only ever runs once,
/// so a version that offered DreamCart+ there and nowhere else could not sell to
/// a single person already using the app, and left no restore path for anyone
/// who reinstalled (App Review 3.1.1).
///
/// Zero-shift rule: the primary button occupies exactly the same slot and
/// geometry as `WelcomeView`'s Next / Get started, so the thumb that swiped
/// through onboarding lands on it without the layout moving. The soft exit
/// below it is always enabled, even mid-purchase, so a stuck StoreKit sheet can
/// never trap anyone inside onboarding (App Review 3.1.1).
struct PlusOfferView: View {
    var presentation: PlusOfferPresentation = .onboarding
    /// Called once the user is done here, bought or not.
    let onDone: () -> Void

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

    private var source: String {
        presentation == .onboarding ? "onboarding" : "profile"
    }

    private var paywallId: String {
        presentation == .onboarding ? "dreamcart_onboarding_plus" : "dreamcart_profile_plus"
    }

    private var exitTitle: String {
        presentation == .onboarding ? String(localized: "Not now") : String(localized: "Maybe later")
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
                    PurchaseRecoveryStatus(plus: true)
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
                priceSlot
                CandyButton(title: ctaTitle, systemImage: "sparkles", enabled: !buying && !restoring && !shop.purchaseRecovery.isRecovering) {
                    buyTask?.cancel()
                    buyTask = Task {
                        if shop.purchaseRecovery.pendingPlus {
                            await shop.reconcilePurchases()
                            confirmActivation()
                        } else {
                            await subscribe()
                        }
                    }
                }
                HStack(spacing: 18) {
                    Button(exitTitle) {
                        Analytics.track("plus_offer_skipped", ["source": source])
                        onDone()
                    }
                    Button(restoring ? "Restoring…" : "Restore") { restore() }
                        .disabled(restoring || buying || shop.purchaseRecovery.isRecovering)
                    Link("Terms", destination: PlusLinks.terms)
                    Link("Privacy", destination: PlusLinks.privacy)
                }
                .font(.dcLabel)
                .foregroundStyle(Theme.subtle(scheme))
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
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
            Analytics.track("plus_offer_shown",
                            ["product_id": PlusPlan.productId, "source": source])
            store.trackPaywallImpression(id: paywallId, oncePerSession: true)
        }
        .onDisappear { buyTask?.cancel() }
        .onChange(of: shop.purchaseRecovery.confirmedPlus) { _, confirmed in
            if confirmed { confirmActivation() }
        }
        .overlay {
            if didSubscribe {
                RewardOverlay(title: String(localized: "\(PlusPlan.name) unlocked"),
                              amount: nil,
                              subtitle: String(localized: "Your daily coins just doubled.")) {
                    onDone()
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
            perk("bolt.fill", String(localized: "Double coins every single day"))
            perk("arrow.triangle.2.circlepath", String(localized: "Spin the wheel as often as you like"))
            // Only claim what `profiles.is_plus` actually grants. Nothing in the
            // backend makes checkout faster; the double grant and the unlimited
            // spin are the whole membership, and a closet filling twice as fast
            // is what they add up to.
            perk("bag.fill", String(localized: "Fill your closet twice as fast"))
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

    /// The billed amount, the most conspicuous price on the page, with the
    /// small disclosure under it (App Review 3.1.2(c), rejected 2026-11-11:
    /// the trial outshone the price). Bridge's approved trial page, ported:
    /// 22 pt bold, above the trial-led button.
    private var priceSlot: some View {
        VStack(spacing: 2) {
            if revenueCatEnabled {
                Text(billedPrice)
                    .font(.dcSection)
                    .foregroundStyle(Theme.ink(scheme))
            }
            Text(disclosure)
                .font(.dcCaption)
                .foregroundStyle(Theme.subtle(scheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 48)
    }

    // MARK: - Copy

    /// What the button charges, or a placeholder that holds the slot until
    /// StoreKit answers. Never an invented amount.
    private var billedPrice: String {
        guard let price = store.plusPrice else { return String(localized: "Loading price…") }
        return String(localized: "\(price)/week")
    }

    private var headline: String {
        store.plusTrialEligible ? String(localized: "Try \(PlusPlan.name) free") : String(localized: "Get \(PlusPlan.name)")
    }

    private var ctaTitle: String {
        guard revenueCatEnabled else { return String(localized: "Continue") }
        if shop.purchaseRecovery.pendingPlus {
            return shop.purchaseRecovery.isRecovering ? String(localized: "Activating membership") : String(localized: "Retry activation")
        }
        if buying { return String(localized: "Starting…") }
        return store.plusTrialEligible
            ? String(localized: "Start \(PlusPlan.trialDays)-day free trial")
            : String(localized: "Get \(PlusPlan.name)")
    }

    /// One concise line, matching the approved fleet pattern: trial length,
    /// price, that it renews, how to cancel. Drops the amount rather than
    /// inventing one when StoreKit has not answered yet.
    private var disclosure: String {
        guard let price = store.plusPrice else {
            return store.plusTrialEligible
                ? String(localized: "\(PlusPlan.trialDays) days free, then a weekly charge. Auto-renews until canceled.")
                : String(localized: "Billed weekly. Auto-renews until canceled.")
        }
        return store.plusTrialEligible
            ? String(localized: "\(PlusPlan.trialDays) days free, then \(price) per week. Auto-renews until canceled. Cancel anytime in Settings.")
            : String(localized: "\(price) per week. Auto-renews until canceled. Cancel anytime in Settings.")
    }

    // MARK: - Actions

    private func subscribe() async {
        guard revenueCatEnabled else {
            onDone()
            return
        }
        buying = true
        store.lastError = nil
        Analytics.track("plus_purchase_started",
                        ["product_id": PlusPlan.productId, "source": source])
        defer {
            buying = false
            buyTask = nil
        }
        guard let accountId = shop.purchaseRecovery.accountId else { return }
        let ok = await store.purchasePlus()
        guard ok else { return }
        shop.purchaseRecovery.beginPlus(accountId: accountId)
        // `is_plus` is set by the RevenueCat webhook, so the profile is the
        // source of truth, not anything the device decided.
        await shop.reconcilePurchases()
        if shop.purchaseRecovery.accountId == accountId { confirmActivation() }
    }

    private func confirmActivation() {
        guard !didSubscribe, shop.purchaseRecovery.confirmedPlus, !shop.purchaseRecovery.pendingPlus,
              shop.purchaseRecovery.accountId == shop.me?.id, shop.me?.isPlus == true else { return }
        Analytics.track("plus_purchased", ["product_id": PlusPlan.productId, "source": source])
        withAnimation { didSubscribe = true }
    }

    private func restore() {
        guard let accountId = shop.purchaseRecovery.accountId else { return }
        restoring = true
        Task {
            defer { restoring = false }
            let ok = await store.restorePlus()
            guard store.lastError == nil else { return }
            if ok {
                shop.purchaseRecovery.beginPlus(accountId: accountId)
                await shop.reconcilePurchases()
                if shop.purchaseRecovery.accountId == accountId { confirmActivation() }
                return
            }
            do {
                let profile = try await shop.refreshProfile()
                guard shop.purchaseRecovery.accountId == accountId else { return }
                if profile.isPlus {
                    withAnimation { didSubscribe = true }
                } else {
                    store.lastError = String(localized: "No previous \(PlusPlan.name) membership on this Apple Account.")
                }
            } catch {
                store.lastError = error.localizedDescription
            }
        }
    }
}

enum PlusLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://jackwallner.github.io/dreamcart/privacy-policy.html")!
    /// Apple's own subscription management screen, which 3.1.2 wants a member
    /// to be able to reach from inside the app.
    static let manage = URL(string: "https://apps.apple.com/account/subscriptions")!
}
