import SwiftUI

struct MainTabView: View {
    @Environment(ShopStore.self) private var shop
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TodayView(tab: $tab)
                .tabItem { Label("Today", systemImage: "sparkles") }.tag(0)

            ShopView()
                .tabItem { Label("Shop", systemImage: "bag.fill") }.tag(1)

            CartView(tab: $tab)
                .tabItem { Label("Cart", systemImage: "cart.fill") }.tag(2)
                .badge(shop.cartIds.count)

            ClosetView()
                .tabItem { Label("Closet", systemImage: "hanger") }.tag(3)

            ProfileView()
                .tabItem { Label("You", systemImage: "person.fill") }.tag(4)
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
