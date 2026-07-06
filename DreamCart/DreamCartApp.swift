import SwiftUI

@main
struct DreamCartApp: App {
    @State private var auth = AuthController()
    @State private var shop = ShopStore()
    @State private var store = StoreController()
    @AppStorage("appearance") private var appearance = Appearance.light.rawValue

    init() {
        // Product art is generated on demand (pollinations); cache aggressively
        // so a shot only renders once per device.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(shop)
                .environment(store)
                .tint(Theme.violet)
                .preferredColorScheme((Appearance(rawValue: appearance) ?? .light).colorScheme)
                .task {
                    await auth.bootstrap()
                    if auth.state == .signedIn {
                        store.configure(userId: await SupabaseClient.shared.currentUserId)
                        await shop.refreshAll()
                        await shop.reconcilePurchases()
                    }
                }
        }
    }
}
