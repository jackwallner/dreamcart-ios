import SwiftUI

struct MainTabView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }.tag(AppTab.today)

            ForYouView()
                .tabItem { Label("For You", systemImage: "hand.thumbsup.fill") }.tag(AppTab.forYou)

            CartView()
                .tabItem { Label("Cart", systemImage: "cart.fill") }.tag(AppTab.cart)
                .badge(shop.cartIds.count)

            ClosetView()
                .tabItem { Label("Closet", systemImage: "hanger") }.tag(AppTab.closet)

            ProfileView()
                .tabItem { Label("You", systemImage: "person.fill") }.tag(AppTab.profile)
        }
        .onChange(of: router.selectedTab) { old, new in
            Analytics.track("tab_switch", ["from": old.rawValue, "to": new.rawValue])
        }
    }
}

// Shared wallet button → Coin Shop, dropped into each tab's toolbar.
struct WalletToolbar: ViewModifier {
    @Environment(ShopStore.self) private var shop
    @Binding var showCoinShop: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                WalletPill(coins: shop.coins) { showCoinShop = true }
            }
        }
        .sheet(isPresented: $showCoinShop) { CoinShopView() }
    }
}

extension View {
    func walletToolbar(_ show: Binding<Bool>) -> some View {
        modifier(WalletToolbar(showCoinShop: show))
    }
}
