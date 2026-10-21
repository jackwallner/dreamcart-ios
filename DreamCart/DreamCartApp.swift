import SwiftUI

@main
struct DreamCartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var auth = AuthController()
    @State private var shop = ShopStore()
    @State private var store = StoreController()
    @State private var upsell = UpsellCoordinator()
    @State private var router = RouteCoordinator()
    @State private var notifications = LocalNotificationCoordinator()
    @State private var shipping = ShippingAddressStore()
    @AppStorage("appearance") private var appearance = Appearance.light.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Product art is generated on demand (pollinations); cache aggressively
        // so a shot only renders once per device.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        // Serif navigation titles so system page titles match the editorial voice.
        Theme.configureNavigationBarAppearance()
        // Keep the hidden system tab bar fully clear behind the custom floating navigation.
        Theme.configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // App Review needs a screenshot of the DreamCart+ purchase screen,
            // and reaching it normally means a fresh account plus the whole
            // onboarding run. This renders the real view directly, under a
            // StoreKit Testing configuration so the price on it is a real one.
            if ProcessInfo.processInfo.environment["DREAMCART_PLUS_SHOT"] == "1" {
                plusShotHarness
            } else {
                root
            }
            #else
            root
            #endif
        }
    }

    #if DEBUG
    private var plusShotHarness: some View {
        PlusOfferView(presentation: .onboarding) {}
            .environment(shop)
            .environment(store)
            .tint(Theme.violet)
            .preferredColorScheme(.light)
            .task { store.configure(userId: nil) }
    }
    #endif

    private var root: some View {
            RootView()
                .environment(auth)
                .environment(shop)
                .environment(store)
                .environment(upsell)
                .environment(router)
                .environment(notifications)
                .environment(shipping)
                .tint(Theme.violet)
                .preferredColorScheme((Appearance(rawValue: appearance) ?? .light).colorScheme)
                .onOpenURL { router.receive(url: $0) }
                .task {
                    Analytics.track("session_start")
                    ConversionDiagnostics.recordAppOpen()
                    #if DEBUG && HAS_REVENUECAT
                    if RevenueCatProbe.isEnabled {
                        // The real path only configures RevenueCat once someone
                        // is signed in, which a fresh simulator never is. The
                        // probe configures directly and fires the same impression
                        // entry point the real upsell screens call.
                        store.configure(userId: nil)
                        store.trackPaywallImpression(id: RevenueCatProbe.impressionID)
                        if RevenueCatProbe.wantsPurchase {
                            await store.runProbePurchase()
                        }
                    }
                    #endif
                    #if DEBUG
                    if DuoScreenshotMode.isSeeded {
                        await DuoScreenshotMode.seed(auth: auth, shop: shop, shipping: shipping)
                        router.setReadiness(signedIn: true, catalogReady: !shop.products.isEmpty)
                        return
                    }
                    #endif
                    AppDelegate.onNotificationRoute = { userInfo in
                        router.receive(notificationUserInfo: userInfo)
                    }
                    await notifications.refreshStatus()
                    await auth.bootstrap()
                    if auth.state == .signedIn {
                        store.configure(userId: await SupabaseClient.shared.currentUserId)
                        await shop.refreshAll()
                        await shop.reconcilePurchases()
                    } else if auth.state == .guest {
                        await shop.refreshCatalogForGuest()
                    }
                    router.setReadiness(signedIn: auth.state == .signedIn || auth.state == .guest,
                                        catalogReady: !shop.products.isEmpty)
                    _ = router.consumePendingRoute()
                }
                .onChange(of: scenePhase) { _, new in
                    guard new == .background else { return }
                    Analytics.track("session_end")
                    Task { await Analytics.flushNow() }
                }
    }
}
