import SwiftUI

@main
struct DreamCartApp: App {
    @State private var auth = AuthController()
    @State private var shop = ShopStore()
    @State private var store = StoreController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(shop)
                .environment(store)
                .tint(Theme.violet)
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
