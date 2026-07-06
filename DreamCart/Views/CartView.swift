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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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

// The dopamine payoff: a card-flip reveal of everything you just "bought".
struct UnboxingView: View {
    let items: [Product]
    let onDone: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var revealed = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            ConfettiBurst().ignoresSafeArea()
            VStack(spacing: 18) {
                Text("It's yours!")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink(scheme))
                Text("\(items.count) new piece\(items.count == 1 ? "" : "s") delivered to your closet")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.subtle(scheme))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, p in
                            VStack(spacing: 8) {
                                RemoteImage(url: p.imageUrl, rarity: p.rarityKind)
                                    .frame(width: 150, height: 185)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(p.rarityKind.color, lineWidth: p.rarityKind.glow ? 3 : 0))
                                Text(p.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.ink(scheme))
                                    .lineLimit(1).frame(width: 150)
                            }
                            .scaleEffect(revealed ? 1 : 0.4)
                            .opacity(revealed ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6)
                                .delay(Double(idx) * 0.12), value: revealed)
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .frame(height: 240)

                CandyButton(title: "Love it", systemImage: "heart.fill") { onDone() }
                    .padding(.horizontal, 50)
            }
            .padding(.vertical, 30)
        }
        .onAppear { Haptics.celebrate(); revealed = true }
    }
}
