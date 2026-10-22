import SwiftUI

struct MainTabView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Tabs mount lazily on first visit (like TabView), then stay alive so
    // their navigation/scroll state survives switching away.
    @State private var mounted: Set<AppTab> = [.today]
    @State private var barHeight: CGFloat = 0
    /// The container's width and fold, measured so the unfolded iPhone Duo can
    /// put the browsing tabs and the Cart on opposite sides of the fold.
    @State private var paneGeometry = PaneGeometry(width: 0, fold: nil)

    /// Unfolded, the Cart has its own pane beside whatever is being browsed,
    /// so adding a piece lands in view and it is never a tab.
    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    var body: some View {
        @Bindable var router = router
        // Not a TabView: its pages are UIKit-hosted, so a safeAreaInset at
        // this level never reached them — content slid under the floating bar
        // and the system still reserved a "shadow" bar slot of its own. A
        // ZStack is pure SwiftUI, so the inset below genuinely occupies the
        // slot the system tab bar used to.
        //
        // Opening or closing the Duo only moves these frames, so no tab is
        // rebuilt and each keeps its navigation and scroll position.
        ZStack(alignment: .topLeading) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                if mounted.contains(tab) {
                    let isPane = isCartPane(tab)
                    PaneCoverHost(isActive: split != nil) { tabRoot(tab) }
                        // Each pane is phone-width, so its screen lays out as on a phone.
                        .environment(\.horizontalSizeClass, split == nil ? horizontalSizeClass : .compact)
                        // The Cart pane has no tab bar beneath it to make room for.
                        .environment(\.floatingTabBarHeight, isPane ? 0 : barHeight)
                        .environment(\.docksFloatingTabBar, split != nil)
                        .frame(maxWidth: paneWidth(tab), maxHeight: .infinity)
                        .padding(.leading, isPane ? split?.secondaryX ?? 0 : 0)
                        .opacity(isVisible(tab) ? 1 : 0)
                        .allowsHitTesting(isVisible(tab))
                        .accessibilityHidden(!isVisible(tab))
                }
            }
        }
        // Measured at the window's width, never the panes': the ZStack would
        // otherwise shrink to the leading pane and undo the split it measured.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomLeading) {
            if !router.isTabBarHidden {
                FloatingTabBar(selection: $router.selectedTab, cartCount: shop.cartIds.count,
                               showsCart: split == nil)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { barHeight = $0 }
                    // Within the browsing pane, never across the fold.
                    .frame(maxWidth: split?.primaryWidth ?? .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        // Keep the bar pinned when the keyboard rises (matches system tab bar).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.easeOut(duration: 0.18), value: router.isTabBarHidden)
        .onChange(of: split != nil, initial: true) { _, isSplit in
            guard isSplit else { return }
            mounted.insert(.cart)
            if router.selectedTab == .cart { router.selectedTab = .today }
        }
        .onChange(of: router.selectedTab) { old, new in
            // Routes can still ask for the Cart tab; unfolded it is already open.
            if new == .cart, split != nil {
                router.selectedTab = old
                return
            }
            mounted.insert(new)
            Analytics.track("tab_switch", ["from": old.rawValue, "to": new.rawValue])
        }
        #if DEBUG
        .task { await DuoScreenshotMode.runTour(router: router, shop: shop, isSplit: { split != nil }) }
        #endif
    }

    private func isCartPane(_ tab: AppTab) -> Bool { tab == .cart && split != nil }

    private func isVisible(_ tab: AppTab) -> Bool {
        router.selectedTab == tab || isCartPane(tab)
    }

    private func paneWidth(_ tab: AppTab) -> CGFloat {
        guard let split else { return .infinity }
        return tab == .cart ? split.secondaryWidth : split.primaryWidth
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
    /// False on the unfolded Duo, where the Cart is a pane of its own.
    let showsCart: Bool
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
            ForEach(items.filter { showsCart || $0.tab != .cart }, id: \.tab) { item in
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
        .frame(width: showsCart ? 355 : 300)
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
    /// True in an unfolded Duo pane, where the pane is too short for scroll
    /// content to rest under the bar, so the bar gets a band of its own.
    @Entry var docksFloatingTabBar: Bool = false
}

/// Reserve the floating tab bar's slot at the bottom of a tab root's content.
/// Applied inside each tab's NavigationStack (on the scroll content) because
/// the stacks are UIKit-hosted and don't inherit a safeAreaInset placed on
/// their SwiftUI ancestor.
struct FloatingTabBarReservation: ViewModifier {
    @Environment(\.floatingTabBarHeight) private var barHeight
    @Environment(\.docksFloatingTabBar) private var docked
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: barHeight)
                .background { if docked && barHeight > 0 { dock } }
        }
    }

    /// Scroll content ends above the bar instead of passing under it, fading
    /// out like the Cart pane's checkout bar beside it.
    private var dock: some View {
        Theme.bg(scheme)
            .overlay(alignment: .top) {
                LinearGradient(colors: [Theme.bg(scheme).opacity(0), Theme.bg(scheme)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 20)
                    .offset(y: -20)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .bottom)
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
        .paneSheet(isPresented: $showCoinShop) { CoinShopView() }
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
