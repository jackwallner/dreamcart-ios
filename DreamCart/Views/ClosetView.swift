import SwiftUI

struct ClosetView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @State private var showCoinShop = false
    @State private var category: String? = nil
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsCard
                    NavigationLink { OutfitBuilderView() } label: { styleBuilderCard }
                        .buttonStyle(PressableStyle())

                    if shop.isLoading && shop.closet.isEmpty {
                        ProgressView("Loading your closet…")
                            .font(.dcBody)
                            .padding(.top, 40)
                    } else if shop.closet.isEmpty {
                        EmptyState(icon: "hanger", title: "Your closet is empty",
                                   message: "Buy your first piece and it lands here.")
                            .padding(.top, 30)
                    } else {
                        SectionHeader(title: "Your pieces", subtitle: "\(shop.closet.count) owned")
                            .padding(.horizontal, 4)
                        categoryBar
                        LazyVGrid(columns: cols, spacing: 18) {
                            ForEach(filtered) { p in
                                NavigationLink(value: p) { ClosetTile(product: p) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Closet")
            .walletToolbar($showCoinShop)
            .navigationDestination(for: Product.self) { p in
                ProductDetailView(product: detailProduct(p))
            }
            .task { await shop.loadOutfits() }
        }
    }

    private var ownedCategories: [String] {
        Array(Set(shop.closet.map { $0.category })).sorted()
    }
    private var filtered: [Product] {
        guard let c = category else { return shop.closet }
        return shop.closet.filter { $0.category == c }
    }

    private func detailProduct(_ product: Product) -> ProductWithBrand {
        if let catalogProduct = shop.products.first(where: { $0.id == product.id }) {
            return catalogProduct
        }
        return ProductWithBrand(
            id: product.id,
            brandId: product.brandId,
            name: product.name,
            category: product.category,
            slot: product.slot,
            styleTags: product.styleTags,
            colorName: product.colorName,
            price: product.price,
            rarity: product.rarity,
            description: product.description,
            imageUrl: product.imageUrl,
            dropDate: product.dropDate,
            brands: shop.brandById[product.brandId]
        )
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", selected: category == nil) { category = nil }
                ForEach(ownedCategories, id: \.self) { c in
                    FilterChip(label: categoryLabel(c), selected: category == c) {
                        category = category == c ? nil : c
                    }
                }
            }
        }
    }

    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "headwear", "hat": return "Hats"
        case "eyewear", "sunglasses": return "Shades"
        case "footwear", "shoes": return "Shoes"
        case "top": return "Tops"
        case "bottom": return "Bottoms"
        case "bag": return "Bags"
        case "accessory": return "Extras"
        default: return category.capitalized
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat("\(shop.me?.itemsOwned ?? shop.closet.count)", "Owned", "bag.fill")
            divider
            stat(Format.coinsShort(shop.me?.lifetimeSpent ?? 0), "Spent", "creditcard.fill")
            divider
            stat("\(shop.me?.bestStreak ?? 0)", "Best streak", "flame.fill")
        }
        .padding(.vertical, 16)
        .cardStyle(scheme)
    }

    private var divider: some View {
        Rectangle().fill(Theme.subtle(scheme).opacity(0.15)).frame(width: 1, height: 40)
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.dcIconM).foregroundStyle(Theme.violet)
            Text(value).font(.dcStat)
                .foregroundStyle(Theme.ink(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.dcCaption)
                .foregroundStyle(Theme.subtle(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var styleBuilderCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Theme.candy).frame(width: 52, height: 52)
                Image(systemName: "figure.arms.open").font(.dcIconL).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Dress up your avatar")
                    .font(.dcCard)
                    .foregroundStyle(Theme.ink(scheme))
                Text("Put your pieces on a model and save the look")
                    .font(.dcSub)
                    .foregroundStyle(Theme.subtle(scheme))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.subtle(scheme))
        }
        .padding(16)
        .cardStyle(scheme)
    }
}

struct ClosetTile: View {
    let product: Product
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: product.imageUrl, rarity: product.rarityKind)
                .aspectRatio(0.82, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
                .overlay(alignment: .topLeading) { RarityTag(rarity: product.rarityKind).padding(6) }
            Text(product.name)
                .font(.dcItem)
                .foregroundStyle(Theme.ink(scheme))
                .lineLimit(2, reservesSpace: true)
        }
    }
}
