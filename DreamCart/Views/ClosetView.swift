import SwiftUI

struct ClosetView: View {
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    @Environment(\.colorScheme) private var scheme

    @State private var showCoinShop = false
    @State private var category: String?
    @State private var query = ""
    @State private var sort: ClosetSort = .newest

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if auth.isGuest {
                            GuestGateState(icon: "hanger",
                                           title: "Your closet lives in your account",
                                           message: "Sign in so everything you buy is saved and ready to style into outfits.",
                                           feature: "closet_tab")
                        } else {
                            collectionHeader

                            if shop.isLoading && shop.closet.isEmpty {
                                ProgressView("Loading your closet…")
                                    .font(.dcBody)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                            } else if shop.closet.isEmpty {
                                EmptyState(
                                    icon: "hanger",
                                    title: "Your closet is empty",
                                    message: "Pieces you buy stay here so you can revisit your collection anytime."
                                )
                                .padding(.top, 40)
                            } else {
                                controls
                                if !highlightedProducts.isEmpty {
                                    newHaulSection.id("new-haul")
                                }
                                collectionSection
                            }
                        }
                    }
                    .padding(16)
                }
                .onAppear { scrollToHighlight(using: proxy) }
                .onChange(of: router.highlightedClosetIds) { _, _ in
                    scrollToHighlight(using: proxy)
                }
            }
            .reservesFloatingTabBar()
            .background(Theme.bg(scheme))
            .navigationTitle("Closet")
            .walletToolbar($showCoinShop)
        }
    }

    private var collectionHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.candy)
                    .frame(width: 58, height: 58)
                Image(systemName: "hanger")
                    .font(.dcIconL)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Your collection")
                    .font(.dcCard)
                    .foregroundStyle(Theme.ink(scheme))
                Text(shop.closet.count == 1 ? "1 piece owned" : "\(shop.closet.count) pieces owned")
                    .font(.dcSub)
                    .foregroundStyle(Theme.subtle(scheme))
            }
            Spacer()
        }
        .padding(16)
        .cardStyle(scheme)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.subtle(scheme))
                TextField("Search your closet", text: $query)
                    .font(.dcBodyText)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.subtle(scheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear closet search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .cardStyle(scheme)

            HStack(spacing: 10) {
                categoryBar
                Menu {
                    Picker("Sort closet", selection: $sort) {
                        ForEach(ClosetSort.allCases) { option in
                            Label(option.label, systemImage: option.icon).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.dcIconS)
                        .foregroundStyle(Theme.violet)
                        .frame(width: 42, height: 38)
                        .background(.thinMaterial, in: Capsule())
                }
                .accessibilityLabel("Sort closet, \(sort.label)")
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", selected: category == nil) { category = nil }
                ForEach(ownedCategories, id: \.self) { value in
                    FilterChip(label: categoryLabel(value), selected: category == value) {
                        category = category == value ? nil : value
                    }
                }
            }
        }
    }

    private var newHaulSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "New haul", subtitle: "Just added to your closet")
                Spacer()
                Button("Done") { router.clearClosetHighlight() }
                    .font(.dcLabel)
                    .foregroundStyle(Theme.violet)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(highlightedProducts) { product in
                        NavigationLink {
                            ProductDetailView(product: detailProduct(product))
                        } label: {
                            ClosetTile(product: product, highlighted: true)
                                .frame(width: 160)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .strokeBorder(Theme.violet.opacity(0.22), lineWidth: 1)
        )
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: query.isEmpty ? "All pieces" : "Search results",
                subtitle: filteredProducts.count == 1 ? "1 piece" : "\(filteredProducts.count) pieces"
            )
            if filteredProducts.isEmpty {
                EmptyState(icon: "magnifyingglass", title: "Nothing matches", message: "Try another search or category.")
            } else {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(filteredProducts) { product in
                        NavigationLink {
                            ProductDetailView(product: detailProduct(product))
                        } label: {
                            ClosetTile(product: product, highlighted: router.highlightedClosetIds.contains(product.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var ownedCategories: [String] {
        Array(Set(shop.closet.map(\.category))).sorted { categoryLabel($0) < categoryLabel($1) }
    }

    private var highlightedProducts: [Product] {
        shop.closet.filter { router.highlightedClosetIds.contains($0.id) }
    }

    private var filteredProducts: [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selected = shop.closet.filter { product in
            let matchesCategory = category == nil || product.category == category
            let matchesQuery = trimmed.isEmpty
                || product.name.lowercased().contains(trimmed)
                || product.colorName.lowercased().contains(trimmed)
                || product.styleTags.contains { $0.lowercased().contains(trimmed) }
            return matchesCategory && matchesQuery
        }
        return selected.sorted { lhs, rhs in
            switch sort {
            case .newest:
                return shop.closetAcquiredAt[lhs.id, default: ""] > shop.closetAcquiredAt[rhs.id, default: ""]
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .priceHigh:
                if lhs.price != rhs.price { return lhs.price > rhs.price }
                return lhs.name < rhs.name
            case .priceLow:
                if lhs.price != rhs.price { return lhs.price < rhs.price }
                return lhs.name < rhs.name
            }
        }
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

    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "headwear", "hat": return "Hats"
        case "eyewear", "sunglasses": return "Shades"
        case "footwear", "shoes": return "Shoes"
        case "top": return "Tops"
        case "bottom": return "Bottoms"
        case "dress": return "Dresses"
        case "outerwear": return "Outerwear"
        case "bag": return "Bags"
        case "jewelry": return "Jewelry"
        case "accessory": return "Extras"
        default: return category.capitalized
        }
    }

    private func scrollToHighlight(using proxy: ScrollViewProxy) {
        guard !router.highlightedClosetIds.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo("new-haul", anchor: .top)
            }
        }
    }
}

private enum ClosetSort: String, CaseIterable, Identifiable {
    case newest
    case name
    case priceHigh
    case priceLow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "Newest"
        case .name: return "Name"
        case .priceHigh: return "Price: high to low"
        case .priceLow: return "Price: low to high"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "clock"
        case .name: return "textformat"
        case .priceHigh: return "arrow.down"
        case .priceLow: return "arrow.up"
        }
    }
}

struct ClosetTile: View {
    let product: Product
    var highlighted = false

    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .headline) private var nameHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(url: product.imageUrl, rarity: product.rarityKind)
                .aspectRatio(0.82, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
                .overlay(alignment: .topLeading) { RarityTag(rarity: product.rarityKind).padding(7) }
                .overlay(alignment: .topTrailing) {
                    if highlighted {
                        Label("NEW", systemImage: "sparkles")
                            .font(.dcBadge)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.pink, in: Capsule())
                            .padding(7)
                    }
                }
            Text(product.name)
                .font(.dcItem)
                .foregroundStyle(Theme.ink(scheme))
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: nameHeight, alignment: .topLeading)
        }
        .contentShape(Rectangle())
    }
}
