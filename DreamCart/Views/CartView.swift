import SwiftUI

struct CartView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCoinShop = false
    @State private var showCheckout = false
    @State private var unboxing: [Product]? = nil

    var body: some View {
        NavigationStack {
            Group {
                if shop.cartProducts.isEmpty {
                    ScrollView {
                        VStack(spacing: 24) {
                            EmptyState(icon: "cart", title: "Your cart is empty",
                                       message: "Add pieces you love. Checkout is free with coins.")
                            CandyButton(title: "Browse shop", systemImage: "bag.fill") {
                                router.selectedTab = .today
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
                        Color.clear.frame(height: 120)
                    }
                }
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Cart")
            .walletToolbar($showCoinShop)
            .safeAreaInset(edge: .bottom) {
                if !shop.cartProducts.isEmpty { checkoutBar }
            }
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
        .overlay {
            if let items = unboxing {
                UnboxingView(items: items) {
                    if reduceMotion { unboxing = nil }
                    else { withAnimation { unboxing = nil } }
                }
            }
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
                        showCoinShop = true
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

// The dopamine payoff: one big centered reveal per piece — glow ring, confetti,
// the full name front and center. Swipe through when the haul has several.
struct UnboxingView: View {
    let items: [Product]
    let onDone: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var page = 0
    @State private var burst = 0
    @State private var stage = 0
    @State private var haloPulse = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            LinearGradient(colors: [Theme.violet.opacity(0.35), .clear, Theme.pink.opacity(0.3)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ForEach(0...burst, id: \.self) { _ in
                ConfettiBurst().ignoresSafeArea()
            }

            VStack(spacing: 14) {
                Text("IT'S YOURS")
                    .font(.dcHero)
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink(scheme))
                    .scaleEffect(stage >= 1 ? 1 : 0.82)
                    .opacity(stage >= 1 ? 1 : 0)
                Text(items.count == 1 ? "Delivered to your closet"
                                      : "\(items.count) new pieces delivered to your closet")
                    .font(.dcBodyText)
                    .foregroundStyle(Theme.subtle(scheme))
                    .opacity(stage >= 2 ? 1 : 0)

                TabView(selection: $page) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, p in
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(p.rarityKind.color.opacity(haloPulse ? 0.42 : 0.24))
                                    .frame(width: 260, height: 260)
                                    .blur(radius: 50)
                                RemoteImage(url: p.imageUrl, rarity: p.rarityKind)
                                    .frame(width: 240, height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(p.rarityKind.color.opacity(p.rarityKind.glow ? 1 : 0.4),
                                                      lineWidth: p.rarityKind.glow ? 4 : 1.5))
                                    .shadow(color: p.rarityKind.color.opacity(0.5), radius: 28, y: 10)
                            }
                            VStack(spacing: 6) {
                                RarityTag(rarity: p.rarityKind)
                                Text(p.name)
                                    .font(.dcTitle)
                                    .foregroundStyle(Theme.ink(scheme))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .scaleEffect(revealed ? 1 : 0.35)
                        .opacity(revealed ? 1 : 0)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
                .frame(height: 440)
                .onChange(of: page) { _, _ in
                    if !reduceMotion { Haptics.soft(); burst += 1 }
                }

                CandyButton(title: "Love it", systemImage: "heart.fill") { onDone() }
                    .padding(.horizontal, 50)
                    .opacity(stage >= 3 ? 1 : 0)
            }
            .padding(.vertical, 24)
        }
        .onAppear {
            Haptics.celebrate()
            guard !reduceMotion else {
                revealed = true
                stage = 3
                haloPulse = true
                return
            }
            withAnimation(.easeOut(duration: 0.28)) { stage = 1 }
            withAnimation(.easeOut(duration: 0.3).delay(0.15)) { stage = 2 }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.2)) {
                revealed = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.48)) { stage = 3 }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.35)) {
                haloPulse = true
            }
        }
    }
}
