import SwiftUI

struct MainTabView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            TodayView().tag(AppTab.today)
            ForYouView().tag(AppTab.forYou)
            CartView().tag(AppTab.cart)
            ClosetView().tag(AppTab.closet)
            ProfileView().tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            if !router.isTabBarHidden {
                FloatingTabBar(selection: $router.selectedTab, cartCount: shop.cartIds.count)
                    .ignoresSafeArea(.keyboard)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: router.isTabBarHidden)
        .onChange(of: router.selectedTab) { old, new in
            Analytics.track("tab_switch", ["from": old.rawValue, "to": new.rawValue])
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let cartCount: Int
    @Environment(\.colorScheme) private var scheme

    private let items: [(tab: AppTab, title: String, icon: String)] = [
        (.today, "Today", "sparkles"),
        (.forYou, "For You", "hand.thumbsup.fill"),
        (.cart, "Cart", "cart.fill"),
        (.closet, "Closet", "hanger"),
        (.profile, "You", "person.fill"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.tab) { item in
                Button {
                    Haptics.select()
                    selection = item.tab
                } label: {
                    VStack(spacing: 3) {
                        tabIcon(item)
                        Text(item.title)
                            .font(.system(.caption2, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == item.tab ? Theme.violet : Theme.ink(scheme).opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 9)
                    .background {
                        if selection == item.tab {
                            Capsule().fill(Theme.violet.opacity(scheme == .dark ? 0.24 : 0.12))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item.tab ? .isSelected : [])
            }
        }
        .frame(width: 355)
        .padding(5)
        .background(Theme.surface(scheme).opacity(0.97), in: Capsule())
        .overlay(Capsule().strokeBorder(.black.opacity(scheme == .dark ? 0 : 0.05), lineWidth: 1))
        .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.10), radius: 12, y: 5)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func tabIcon(_ item: (tab: AppTab, title: String, icon: String)) -> some View {
        Image(systemName: item.icon)
            .font(.system(size: 21, weight: .semibold))
            .frame(height: 24)
            .overlay(alignment: .topTrailing) {
                if item.tab == .cart, cartCount > 0 {
                    Text(cartCount > 99 ? "99+" : "\(cartCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, cartCount > 9 ? 4 : 3)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(Theme.pink, in: Capsule())
                        .offset(x: 10, y: -6)
                }
            }
    }
}

struct WalletToolbar: ViewModifier {
    @Environment(ShopStore.self) private var shop
    @Binding var showCoinShop: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    WalletPill(coins: shop.coins) { showCoinShop = true }
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    WalletPill(coins: shop.coins) { showCoinShop = true }
                }
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
