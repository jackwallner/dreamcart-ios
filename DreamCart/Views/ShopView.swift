import SwiftUI

struct ShopView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @Environment(\.paneCovers) private var paneCovers
    @State private var showCoinShop = false
    @State private var query = ""
    @State private var category: String? = nil

    private let categories: [(key: String, label: String, icon: String)] = [
        ("top", String(localized: "Tops"), "tshirt"), ("bottom", String(localized: "Bottoms"), "figure.walk"),
        ("dress", String(localized: "Dresses"), "figure.dress.line.vertical.figure"),
        ("outerwear", String(localized: "Outerwear"), "coat"), ("shoes", String(localized: "Shoes"), "shoe"),
        ("bag", String(localized: "Bags"), "bag"), ("jewelry", String(localized: "Jewelry"), "sparkle"),
        ("sunglasses", String(localized: "Shades"), "sunglasses"), ("hat", String(localized: "Hats"), "hat.widebrim"),
        ("accessory", String(localized: "Extras"), "scribble.variable"),
    ]

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var cols: [GridItem] { IPadLayout.productColumns(regular: sizeClass == .regular) }

    // ShopView is pushed onto the Today tab's stack. Keeping a second stack
    // here made product taps compete with the host stack and fail to navigate.
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if shop.loadError != nil {
                    LoadErrorBanner()
                        .padding(.horizontal, 16)
                }
                if let error = shop.catalogLoadError {
                    catalogLoadBanner(error)
                        .padding(.horizontal, 16)
                }
                if shop.isLoading && shop.products.isEmpty {
                    ProgressView("Loading the catalog…")
                        .font(.dcBody)
                        .padding(.top, 80)
                } else if !query.isEmpty {
                    grid(shop.search(query))
                } else {
                    categoryBar
                    grid(filtered)
                }
                if shop.isLoadingMoreProducts {
                    ProgressView("Loading more products…")
                        .font(.dcSub)
                        .padding(.vertical, 12)
                }
            }
            .readableWidth()
        }
        .reservesFloatingTabBar()
        .background(Theme.bg(scheme))
        .navigationTitle("Shop")
        // In an unfolded Duo pane iOS lays search along the bottom edge, under
        // the floating tab bar, so there it sits under the title instead.
        .searchable(text: $query,
                    placement: paneCovers == nil ? .automatic : .navigationBarDrawer(displayMode: .always),
                    prompt: String(localized: "Search brands, colors, styles"))
        .walletToolbar($showCoinShop)
    }

    private var filtered: [ProductWithBrand] {
        guard let c = category else { return shop.products }
        return shop.products(category: c)
    }

    private func catalogLoadBanner(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.dcIconM)
                .foregroundStyle(Theme.pink)
            VStack(alignment: .leading, spacing: 3) {
                Text("Some products are still missing")
                    .font(.dcBody)
                    .foregroundStyle(Theme.ink(scheme))
                Text(error)
                    .font(.dcSub)
                    .foregroundStyle(Theme.subtle(scheme))
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button("Retry") { shop.retryRemainingCatalog() }
                .font(.dcLabel)
                .foregroundStyle(Theme.violet)
                .disabled(shop.isLoadingMoreProducts)
        }
        .padding(14)
        .cardStyle(scheme)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: String(localized: "All"), selected: category == nil) { category = nil }
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
            if items.isEmpty && !shop.isLoading {
                EmptyState(icon: "magnifyingglass", title: String(localized: "Nothing here"),
                           message: shop.loadError == nil
                               ? String(localized: "Try another search or category.")
                               : String(localized: "The catalog could not be loaded. Retry above."))
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: cols, spacing: 18) {
                    ForEach(items) { p in
                        NavigationLink {
                            ProductDetailView(product: p)
                        } label: {
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var cols: [GridItem] { IPadLayout.productColumns(regular: sizeClass == .regular) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(brand.localizedTagline)
                    .font(.dcBodyText)
                    .foregroundStyle(Color.brandText(hex: brand.accentHex, scheme: scheme))
                    .padding(.horizontal, 16)
                LazyVGrid(columns: cols, spacing: 18) {
                    ForEach(shop.products(brandId: brand.id)) { p in
                        NavigationLink {
                            ProductDetailView(product: p)
                        } label: {
                            ProductCard(product: p, owned: shop.ownedIds.contains(p.id),
                                        isNew: shop.newDropIds.contains(p.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .readableWidth()
        }
        .reservesFloatingTabBar()
        .background(Theme.bg(scheme))
        .navigationTitle(brand.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
