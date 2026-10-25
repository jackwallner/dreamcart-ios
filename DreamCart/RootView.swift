import SwiftUI

struct RootView: View {
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(StoreController.self) private var store
    @Environment(RouteCoordinator.self) private var router
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var auth = auth
        ZStack {
            Theme.bg(scheme).ignoresSafeArea()
            switch auth.state {
            case .unknown:
                UnfoldedColumn(showsMark: false) { SplashView() }
            case .signedOut:
                UnfoldedColumn { WelcomeView() }
            case .guest, .signedIn:
                // Stay on the splash through the first catalog load. Auth resolves
                // long before the products arrive, and cutting to the tabs early
                // shows a shell of empty grids rather than the app.
                if shop.hasLoadedOnce {
                    if auth.state == .signedIn && auth.justCompletedOnboarding {
                        // One-time final onboarding step for brand-new users only
                        // (see AuthController.justCompletedOnboarding); clearing
                        // the flag here means it can never show again this run.
                        //
                        // This is the DreamCart+ trial, not the old coin-pack
                        // offer. Asking someone who has not played yet to buy
                        // currency converted nobody; the membership is a smaller
                        // ask and it improves the loop itself. Coin packs are
                        // still one tap away from the wallet pill, and the same
                        // offer stays reachable from the You tab afterwards.
                        UnfoldedColumn {
                            PlusOfferView(presentation: .onboarding) {
                                auth.justCompletedOnboarding = false
                            }
                        }
                        .transition(.opacity)
                    } else {
                        MainTabView().transition(.opacity)
                    }
                } else {
                    UnfoldedColumn(showsMark: false) { SplashView() }.transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: shop.hasLoadedOnce)
        // Any account-based action a guest taps raises this instead of doing
        // the work (AuthController.requireAccount).
        .sheet(isPresented: $auth.promptSignIn) { SignInPromptView() }
        .onChange(of: auth.state) { _, new in
            #if DEBUG
            // The seeded shopper has no server session to load.
            if DuoScreenshotMode.isSeeded { return }
            #endif
            let browsing = new == .signedIn || new == .guest
            router.setReadiness(signedIn: browsing,
                                catalogReady: browsing && !shop.products.isEmpty)
            switch new {
            case .signedIn:
                Task {
                    shop.purchaseRecovery.selectAccount(await SupabaseClient.shared.currentUserId)
                    store.configure(userId: shop.purchaseRecovery.accountId)
                    await shop.refreshAll()
                    await shop.reconcilePurchases()
                    router.setReadiness(signedIn: true, catalogReady: !shop.products.isEmpty)
                    _ = router.consumePendingRoute()
                }
            case .guest:
                shop.purchaseRecovery.selectAccount(nil)
                Task {
                    await shop.refreshCatalogForGuest()
                    router.setReadiness(signedIn: true, catalogReady: !shop.products.isEmpty)
                    _ = router.consumePendingRoute()
                }
            case .unknown, .signedOut:
                shop.purchaseRecovery.selectAccount(nil)
            }
        }
    }
}

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    var body: some View {
        ZStack {
            Theme.candy.ignoresSafeArea()
            VStack(spacing: 18) {
                BagMark(size: 92)
                    .scaleEffect(reduceMotion ? 1 : (pulse ? 1.06 : 0.94))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                Text("DreamCart")
                    .font(.dcHero)
                    .foregroundStyle(.white)
            }
        }
        .onAppear { pulse = true }
    }
}

// The bag glyph from the icon, reusable in-app.
struct BagMark: View {
    var size: CGFloat = 64
    var tint: Color = .white
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(tint)
                .frame(width: size, height: size)
            Circle()
                .strokeBorder(tint, lineWidth: size * 0.09)
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.42)
                .mask(Rectangle().frame(width: size, height: size * 0.5).offset(y: -size * 0.42))
            Image(systemName: "sparkles")
                // BagMark is a parametric logo component, so its glyph tracks the mark size.
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Theme.pink)
        }
        .frame(width: size, height: size * 1.2)
    }
}
