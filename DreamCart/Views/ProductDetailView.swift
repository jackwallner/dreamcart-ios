import SwiftUI

struct ProductDetailView: View {
    let product: ProductWithBrand
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @State private var showCoinShop = false
    @State private var showCheckout = false
    @State private var addedPulse = false
    @State private var unboxing: [Product]? = nil

    private var owned: Bool { shop.ownedIds.contains(product.id) }
    private var inCart: Bool { shop.inCart(product.id) }
    private var brand: Brand? { product.brands }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RemoteImage(url: product.imageUrl, rarity: product.rarityKind)
                    .aspectRatio(0.82, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        favoriteButton.padding(12)
                    }
                    .overlay(alignment: .topLeading) {
                        RarityTag(rarity: product.rarityKind).padding(12)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    if let brand {
                        NavigationLink(value: brand) {
                            Text(brand.name.uppercased())
                                .font(.dcOverline)
                                .tracking(0.6)
                                .foregroundStyle(Color(hex: brand.accentHex))
                        }
                    }
                    Text(product.name)
                        .font(.dcTitle)
                        .foregroundStyle(Theme.ink(scheme))
                    Text(product.description)
                        .font(.dcBodyText)
                        .foregroundStyle(Theme.subtle(scheme))

                    HStack(spacing: 8) {
                        ForEach(product.styleTags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.dcLabel)
                                .foregroundStyle(Theme.violet)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Theme.violet.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.top, 2)
                }

                specRows
                Color.clear.frame(height: 90)
            }
            .padding(16)
        }
        .background(Theme.bg(scheme))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { buyBar }
        .sheet(isPresented: $showCoinShop) { CoinShopView() }
        .sheet(isPresented: $showCheckout) {
            CheckoutView { bought in
                showCheckout = false
                withAnimation { unboxing = bought }
            }
        }
        .overlay {
            if let items = unboxing {
                UnboxingView(items: items) { withAnimation { unboxing = nil } }
            }
        }
    }

    private var favoriteButton: some View {
        Button {
            Task { await shop.toggleFavorite(product.id) }
        } label: {
            Image(systemName: shop.isFavorite(product.id) ? "heart.fill" : "heart")
                .font(.dcIconM)
                .foregroundStyle(shop.isFavorite(product.id) ? Theme.pink : .white)
                .padding(10)
                .background(.black.opacity(0.35), in: Circle())
        }
    }

    private var specRows: some View {
        VStack(spacing: 0) {
            specRow("Color", product.colorName)
            Divider()
            specRow("Category", product.category.capitalized)
            Divider()
            specRow("Rarity", product.rarityKind.label)
        }
        .padding(.horizontal, 14)
        .cardStyle(scheme)
    }

    private func specRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.dcBodyText)
                .foregroundStyle(Theme.subtle(scheme))
            Spacer()
            Text(v).font(.dcBody)
                .foregroundStyle(Theme.ink(scheme))
        }
        .padding(.vertical, 13)
    }

    private var buyBar: some View {
        HStack(spacing: 12) {
            CoinLabel(amount: product.price, size: 20, weight: .heavy)
                .foregroundStyle(Theme.ink(scheme))
            Spacer()
            if owned {
                Label("In your closet", systemImage: "checkmark.seal.fill")
                    .font(.dcBody)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Color.green.gradient, in: Capsule())
            } else {
                Button {
                    // First tap adds and drops you straight into checkout; once
                    // in the cart, the button re-opens checkout (removal lives
                    // in the cart itself).
                    if !inCart { shop.toggleCart(product.id) }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { addedPulse.toggle() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showCheckout = true }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: inCart ? "creditcard.fill" : "cart.badge.plus")
                        Text(inCart ? "Check out" : "Add to cart")
                    }
                    .font(.dcButton)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(inCart ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Theme.candy),
                                in: Capsule())
                    .scaleEffect(addedPulse ? 1.05 : 1)
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("detailCheckoutButton")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.bar)
    }
}
