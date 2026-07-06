import SwiftUI

struct CartView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @State private var showCoinShop = false
    @State private var checkingOut = false
    @State private var unboxing: [Product]? = nil

    var body: some View {
        NavigationStack {
            Group {
                if shop.cartProducts.isEmpty {
                    ScrollView {
                        EmptyState(icon: "cart", title: "Your cart is empty",
                                   message: "Add pieces you love. Checkout is free with coins.")
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
        .overlay {
            if let items = unboxing {
                UnboxingView(items: items) { withAnimation { unboxing = nil } }
            }
        }
    }

    private var checkoutBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(shop.cartProducts.count) item\(shop.cartProducts.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.subtle(scheme))
                Spacer()
                CoinLabel(amount: shop.cartTotal, size: 18, weight: .heavy)
                    .foregroundStyle(Theme.ink(scheme))
            }
            if shop.canAfford {
                CandyButton(title: checkingOut ? "Checking out..." : "Check out",
                            systemImage: "sparkles", enabled: !checkingOut) {
                    Task { await checkout() }
                }
            } else {
                VStack(spacing: 8) {
                    Text("You need \(Format.coins(shop.cartTotal - shop.coins)) more coins")
                        .font(.system(size: 13, weight: .semibold))
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

    private func checkout() async {
        checkingOut = true
        defer { checkingOut = false }
        let bought = shop.cartProducts
        if let r = await shop.checkout(), r.ok {
            Haptics.celebrate()
            withAnimation { unboxing = bought }
        } else {
            Haptics.warning()
        }
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink(scheme))
                    .lineLimit(2)
                CoinLabel(amount: product.price, size: 14, weight: .heavy)
                    .foregroundStyle(Theme.ink(scheme))
            }
            Spacer()
            Button {
                Haptics.tap(); onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.subtle(scheme).opacity(0.5))
            }
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
    @State private var revealed = false
    @State private var page = 0
    @State private var burst = 0

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
                    .font(Theme.display(38, .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink(scheme))
                    .scaleEffect(revealed ? 1 : 0.6)
                    .opacity(revealed ? 1 : 0)
                Text(items.count == 1 ? "Delivered to your closet"
                                      : "\(items.count) new pieces delivered to your closet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.subtle(scheme))

                TabView(selection: $page) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, p in
                        VStack(spacing: 16) {
                            ZStack {
                                // Rarity glow halo behind the shot.
                                Circle()
                                    .fill(p.rarityKind.color.opacity(0.35))
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
                                    .font(Theme.display(22, .semibold))
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
                    Haptics.soft()
                    burst += 1
                }

                CandyButton(title: "Love it", systemImage: "heart.fill") { onDone() }
                    .padding(.horizontal, 50)
            }
            .padding(.vertical, 24)
        }
        .onAppear {
            Haptics.celebrate()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { revealed = true }
        }
    }
}
