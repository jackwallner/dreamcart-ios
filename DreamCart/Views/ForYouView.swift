import SwiftUI

struct ForYouView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGSize = .zero
    @State private var showCoinShop = false
    @State private var acceptedFlash = false

    private var products: [ProductWithBrand] { shop.forYouProducts }
    private var current: ProductWithBrand? { products.first }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 18) {
                    header
                    if let current {
                        card(current, size: proxy.size)
                        controls(current)
                    } else {
                        exhausted
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg(scheme))
            }
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.large)
            .walletToolbar($showCoinShop)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your next obsession")
                    .font(.dcCard)
                    .foregroundStyle(Theme.ink(scheme))
                Text("Pass left. Cart right.")
                    .font(.dcSub)
                    .foregroundStyle(Theme.subtle(scheme))
            }
            Spacer()
            Text("\(products.count) picks")
                .font(.dcLabel)
                .foregroundStyle(Theme.violet)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.violet.opacity(0.1), in: Capsule())
        }
    }

    private func card(_ product: ProductWithBrand, size: CGSize) -> some View {
        NavigationLink {
            ProductDetailView(product: product)
        } label: {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: product.imageUrl, rarity: product.rarityKind, maxPixelSize: 1400)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.75)],
                               startPoint: .center, endPoint: .bottom)
                cardCopy(product)
                swipeOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(product.rarityKind.color.opacity(0.55), lineWidth: 2))
            .shadow(color: product.rarityKind.color.opacity(0.25), radius: 22, y: 12)
            .rotationEffect(.degrees(Double(offset.width / 24)))
            .offset(offset)
        }
        .buttonStyle(.plain)
        .frame(height: min(size.height * 0.62, 560))
        .gesture(dragGesture(product))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.name), \(product.brands?.name ?? "DreamCart"), \(product.rarityKind.label), \(Format.coins(product.price)) coins")
        .accessibilityAction(named: "Pass") { pass(product) }
        .accessibilityAction(named: "Add to cart") { accept(product) }
    }

    private func cardCopy(_ product: ProductWithBrand) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                RarityTag(rarity: product.rarityKind)
                Spacer()
                CoinLabel(amount: product.price, size: 17, weight: .heavy)
                    .foregroundStyle(.white)
            }
            Text(product.brands?.name.uppercased() ?? "DREAMCART")
                .font(.dcOverline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Text(product.name)
                .font(.dcTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text(product.styleTags.prefix(3).map { "#\($0)" }.joined(separator: "  "))
                .font(.dcLabel)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
        }
        .padding(20)
    }

    private var swipeOverlay: some View {
        HStack {
            Text("PASS")
                .foregroundStyle(.white)
                .padding(10)
                .background(.red.opacity(0.9), in: Capsule())
                .opacity(max(0, -offset.width / 100))
            Spacer()
            Text(acceptedFlash ? "CARTED!" : "ADD")
                .foregroundStyle(.white)
                .padding(10)
                .background(.green.opacity(0.9), in: Capsule())
                .opacity(max(0, offset.width / 100))
        }
        .font(.dcButton)
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func controls(_ product: ProductWithBrand) -> some View {
        HStack(spacing: 28) {
            actionButton("xmark", color: .red, label: "Pass") { pass(product) }
            actionButton("cart.badge.plus", color: .green, label: "Add to cart") { accept(product) }
        }
    }

    private func actionButton(_ icon: String, color: Color, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.dcIconL)
                .foregroundStyle(color)
                .frame(width: 64, height: 64)
                .background(Theme.surface(scheme), in: Circle())
                .overlay(Circle().strokeBorder(color.opacity(0.28), lineWidth: 2))
                .shadow(color: color.opacity(0.18), radius: 10, y: 5)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private var exhausted: some View {
        VStack(spacing: 22) {
            EmptyState(icon: "sparkles", title: "You're all caught up",
                       message: "Fresh picks appear as new pieces drop. You can also bring passed items back.")
            CandyButton(title: "Reconsider passes", systemImage: "arrow.counterclockwise") {
                shop.resetRecommendationDismissals()
            }
        }
        .padding(.horizontal, 24)
    }

    private func dragGesture(_ product: ProductWithBrand) -> some Gesture {
        DragGesture()
            .onChanged { offset = $0.translation }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                if projected > 120 { accept(product) }
                else if projected < -120 { pass(product) }
                else { animateReset() }
            }
    }

    private func pass(_ product: ProductWithBrand) {
        animateOut(to: -500) { shop.dismissRecommendation(product.id) }
    }

    private func accept(_ product: ProductWithBrand) {
        acceptedFlash = true
        Haptics.success()
        animateOut(to: 500) {
            _ = shop.addToCart(product.id, recommendation: true)
            acceptedFlash = false
        }
    }

    private func animateOut(to x: CGFloat, completion: @escaping () -> Void) {
        if reduceMotion {
            offset = .zero
            completion()
            return
        }
        withAnimation(.easeIn(duration: 0.18)) { offset.width = x }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            offset = .zero
            completion()
        }
    }

    private func animateReset() {
        if reduceMotion { offset = .zero }
        else { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offset = .zero } }
    }
}
