import SwiftUI

struct CartView: View {
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCoinShop = false
    @State private var showCheckout = false
    @State private var showUpsell = false
    @State private var unboxing: [Product]? = nil

    var body: some View {
        NavigationStack {
            Group {
                if auth.isGuest {
                    ScrollView {
                        GuestGateState(icon: "cart",
                                       title: "The cart needs an account",
                                       message: "Sign in to fill a cart, check out with coins and keep what you buy.",
                                       feature: "cart_tab")
                    }
                } else if shop.cartProducts.isEmpty {
                    ScrollView {
                        VStack(spacing: 24) {
                            EmptyState(icon: "cart", title: "Your cart is empty",
                                       message: "Add pieces you love. Checkout is free with coins.")
                            CandyButton(title: "Browse shop", systemImage: "bag.fill") {
                                router.receive(.shop)
                            }
                            .padding(.horizontal, 32)
                        }
                        .padding(.top, 80)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(shop.cartProducts) { p in
                                CartRow(product: p) { shop.removeFromCart(p.id) }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !shop.cartProducts.isEmpty { checkoutBar }
            }
            // After (outside) the checkout bar's inset, so the bar's slot is
            // reserved below it — checkout stacks above the floating tab bar.
            .reservesFloatingTabBar()
            .background(Theme.bg(scheme))
            .navigationTitle("Cart")
            .walletToolbar($showCoinShop)
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutView { bought in
                showCheckout = false
                if reduceMotion {
                    unboxing = bought
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { unboxing = bought }
                }
            }
        }
        .sheet(isPresented: $showUpsell) { CoinUpsellView(trigger: .insufficientCoins) }
        .overlay {
            if let items = unboxing {
                UnboxingView(items: items) {
                    if reduceMotion { unboxing = nil }
                    else { withAnimation { unboxing = nil } }
                }
            }
        }
        // The unboxing celebration is full-screen; the floating tab bar would
        // otherwise stay drawn on top of it.
        .onChange(of: unboxing == nil) { _, dismissed in
            router.setOverlayVisible(!dismissed)
        }
    }

    private var checkoutBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(shop.cartProducts.count) item\(shop.cartProducts.count == 1 ? "" : "s")")
                    .font(.dcSub)
                    .foregroundStyle(Theme.subtle(scheme))
                Spacer()
                CoinLabel(amount: shop.cartTotal, size: 18, weight: .heavy)
                    .foregroundStyle(Theme.ink(scheme))
            }
            if shop.canAfford {
                CandyButton(title: "Check out", systemImage: "sparkles") {
                    showCheckout = true
                }
                .accessibilityIdentifier("cartCheckoutButton")
            } else {
                VStack(spacing: 8) {
                    Text("You need \(Format.coins(shop.cartTotal - shop.coins)) more coins")
                        .font(.dcLabel)
                        .foregroundStyle(Theme.pink)
                    CandyButton(title: "Get more coins", systemImage: "plus.circle.fill") {
                        showUpsell = true
                    }
                }
            }
        }
        .padding(16)
        .background(.bar)
    }
}

struct CartRow: View {
    let product: Product
    let onRemove: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: product.imageUrl, rarity: product.rarityKind)
                .frame(width: 66, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.dcItem)
                    .foregroundStyle(Theme.ink(scheme))
                    .lineLimit(2, reservesSpace: true)
                CoinLabel(amount: product.price)
                    .foregroundStyle(Theme.ink(scheme))
            }
            Spacer()
            Button {
                Haptics.tap(); onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.dcIconL)
                    .foregroundStyle(Theme.subtle(scheme).opacity(0.5))
            }
            .accessibilityLabel("Remove \(product.name) from cart")
        }
        .padding(12)
        .cardStyle(scheme)
    }
}

// `UnboxingView` (the post-checkout dopamine payoff) now lives in
// Components/Celebration.swift — it stages every purchased item through a
// slot-machine-style suspense/reveal sequence before a "total haul" summary,
// not just one item. Kept as a distinct type there since it's shared with
// ProductDetailView's quick-buy flow too.
