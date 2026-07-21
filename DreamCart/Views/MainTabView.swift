import SwiftUI

struct MainTabView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    // Tabs mount lazily on first visit (like TabView), then stay alive so
    // their navigation/scroll state survives switching away.
    @State private var mounted: Set<AppTab> = [.today]
    @State private var barHeight: CGFloat = 0

    var body: some View {
        @Bindable var router = router
        // Not a TabView: its pages are UIKit-hosted, so a safeAreaInset at
        // this level never reached them — content slid under the floating bar
        // and the system still reserved a "shadow" bar slot of its own. A
        // ZStack is pure SwiftUI, so the inset below genuinely occupies the
        // slot the system tab bar used to.
        ZStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                if mounted.contains(tab) {
                    tabRoot(tab)
                        .opacity(router.selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(router.selectedTab == tab)
                        .accessibilityHidden(router.selectedTab != tab)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !router.isTabBarHidden {
                FloatingTabBar(selection: $router.selectedTab, cartCount: shop.cartIds.count)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { barHeight = $0 }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Each tab root reserves the bar's measured slot via
        // reservesFloatingTabBar() — a safeAreaInset here doesn't reach them
        // (NavigationStack roots are UIKit-hosted and ignore it), which is
        // what let content slide under the bar.
        .environment(\.floatingTabBarHeight, barHeight)
        // Keep the bar pinned when the keyboard rises (matches system tab bar).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.easeOut(duration: 0.18), value: router.isTabBarHidden)
        .onChange(of: router.selectedTab) { old, new in
            mounted.insert(new)
            Analytics.track("tab_switch", ["from": old.rawValue, "to": new.rawValue])
        }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .today: TodayView()
        case .forYou: ForYouView()
        case .cart: CartView()
        case .closet: ClosetView()
        case .profile: ProfileView()
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

extension EnvironmentValues {
    /// Measured height of the floating tab bar (0 while it's hidden).
    @Entry var floatingTabBarHeight: CGFloat = 0
}

/// Reserve the floating tab bar's slot at the bottom of a tab root's content.
/// Applied inside each tab's NavigationStack (on the scroll content) because
/// the stacks are UIKit-hosted and don't inherit a safeAreaInset placed on
/// their SwiftUI ancestor.
struct FloatingTabBarReservation: ViewModifier {
    @Environment(\.floatingTabBarHeight) private var barHeight

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: barHeight)
        }
    }
}

extension View {
    func reservesFloatingTabBar() -> some View {
        modifier(FloatingTabBarReservation())
    }
}

struct WalletToolbar: ViewModifier {
    @Environment(ShopStore.self) private var shop
    @Environment(AuthController.self) private var auth
    @Binding var showCoinShop: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) { walletItem }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) { walletItem }
            }
        }
        .sheet(isPresented: $showCoinShop) { CoinShopView() }
    }

    // A guest has no wallet, so the pill becomes the way into signing up
    // rather than a coin balance that would always read zero.
    @ViewBuilder
    private var walletItem: some View {
        if auth.isGuest {
            Button("Sign in") { auth.requireAccount("wallet") }
                .font(.dcLabel)
                .foregroundStyle(Theme.violet)
        } else {
            WalletPill(coins: shop.coins) { showCoinShop = true }
        }
    }
}

extension View {
    func walletToolbar(_ show: Binding<Bool>) -> some View {
        modifier(WalletToolbar(showCoinShop: show))
    }
}
