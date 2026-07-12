import SwiftUI

struct ShopView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @State private var showCoinShop = false
    @State private var query = ""
    @State private var category: String? = nil

    private let categories: [(key: String, label: String, icon: String)] = [
        ("top", "Tops", "tshirt"), ("bottom", "Bottoms", "figure.walk"),
        ("dress", "Dresses", "figure.dress.line.vertical.figure"),
        ("outerwear", "Outerwear", "coat"), ("shoes", "Shoes", "shoe"),
        ("bag", "Bags", "bag"), ("jewelry", "Jewelry", "sparkle"),
        ("sunglasses", "Shades", "sunglasses"), ("hat", "Hats", "hat.widebrim"),
        ("accessory", "Extras", "scribble.variable"),
    ]

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if shop.loadError != nil {
                        LoadErrorBanner()
                            .padding(.horizontal, 16)
                    }
                    if !query.isEmpty {
                        grid(shop.search(query))
                    } else {
                        categoryBar
                        grid(filtered)
                    }
                }
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Shop")
            .searchable(text: $query, prompt: "Search brands, colors, styles")
            .walletToolbar($showCoinShop)
            .navigationDestination(for: ProductWithBrand.self) { ProductDetailView(product: $0) }
            .navigationDestination(for: Brand.self) { BrandView(brand: $0) }
        }
    }

    private var filtered: [ProductWithBrand] {
        guard let c = category else { return shop.products }
        return shop.products(category: c)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", selected: category == nil) { category = nil }
                ForEach(categories, id: \.key) { c in
                    FilterChip(label: c.label, icon: c.icon, selected: category == c.key) {
                        category = category == c.key ? nil : c.key
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }

    private func grid(_ items: [ProductWithBrand]) -> some View {
        Group {
            if items.isEmpty {
                EmptyState(icon: "magnifyingglass", title: "Nothing here",
                           message: "Try another search or category.")
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: cols, spacing: 18) {
                    ForEach(items) { p in
                        NavigationLink(value: p) {
                            ProductCard(product: p, owned: shop.ownedIds.contains(p.id),
                                        isNew: shop.newDropIds.contains(p.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
    }
}

struct BrandView: View {
    let brand: Brand
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(brand.tagline)
                    .font(.dcBodyText)
                    .foregroundStyle(Color(hex: brand.accentHex))
                    .padding(.horizontal, 16)
                LazyVGrid(columns: cols, spacing: 18) {
                    ForEach(shop.products(brandId: brand.id)) { p in
                        NavigationLink(value: p) {
                            ProductCard(product: p, owned: shop.ownedIds.contains(p.id),
                                        isNew: shop.newDropIds.contains(p.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.bg(scheme))
        .navigationTitle(brand.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
