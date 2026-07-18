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
    }

    var body: some Scene {
        WindowGroup {
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
                    AppDelegate.onNotificationRoute = { userInfo in
                        router.receive(notificationUserInfo: userInfo)
                    }
                    await notifications.refreshStatus()
                    await auth.bootstrap()
                    if auth.state == .signedIn {
                        store.configure(userId: await SupabaseClient.shared.currentUserId)
                        await shop.refreshAll()
                        await shop.reconcilePurchases()
                    }
                    router.setReadiness(signedIn: auth.state == .signedIn,
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
}
