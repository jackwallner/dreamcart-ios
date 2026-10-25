import SwiftUI

struct ProductDetailView: View {
    let product: ProductWithBrand
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isUnfoldedPane) private var isUnfoldedPane
    @Environment(\.floatingTabBarHeight) private var tabBarHeight
    @Environment(\.dismiss) private var dismiss
    @State private var showCoinShop = false
    @State private var showCheckout = false
    @State private var addedPulse = false
    @State private var unboxing: [Product]? = nil
    @State private var favoriteError: String?
    @State private var updatingFavorite = false
    @State private var viewedAt: Date?
    // The tab this detail was pushed onto, captured at appear so the matching
    // pop decrements the same tab even after the selected tab has changed.
    @State private var owningTab: AppTab?
    /// Where the scroll view's visible area starts (below the navigation
    /// bar) and where the buy bar starts, in window coordinates, and the
    /// visible width. Scroll geometry's content insets and a GeometryProxy's
    /// bottom inset both overcounted the buy bar here, so the photo always
    /// fell to its floor.
    @State private var visibleTop: CGFloat = 0
    @State private var barTop: CGFloat = 0
    @State private var visibleWidth: CGFloat = 0
    @State private var infoHeight: CGFloat = 0

    private var owned: Bool { shop.ownedIds.contains(product.id) }
    private var inCart: Bool { shop.inCart(product.id) }
    private var brand: Brand? { product.brands }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DetailHeroLayout.spacing) {
                VStack(alignment: .leading, spacing: DetailHeroLayout.spacing) {
                    photo
                    info
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { infoHeight = $0 }
                }
                .frame(minHeight: hero?.height, alignment: .top)

                specRows
                completeTheLook
            }
            .padding(DetailHeroLayout.padding)
        }
        // Pushed in a pane, the scroll view's frame already starts below the
        // navigation bar and still reports that bar as its top inset (82 pt
        // unfolded, 24 pt folded), so adding the two counted it twice.
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(proxy.frame(in: .global).minY, proxy.safeAreaInsets.top)
        } action: { visibleTop = $0 }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing
        } action: { visibleWidth = $0 }
        .background(Theme.bg(scheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        // In a pane iOS 27.1 may put the navigation bar in a column beside
        // the fold, with the back button there and the page 84 pt short of
        // it, so the pane draws its own back button over the page instead.
        .toolbar(isUnfoldedPane ? .hidden : .automatic, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if isUnfoldedPane { paneBackButton }
        }
        .safeAreaInset(edge: .bottom) { buyBar }
        // Unfolded the tab bar stays below the buy bar (folded it hides).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: isUnfoldedPane ? tabBarHeight : 0)
        }
        .ignoresSafeArea(.container, edges: isUnfoldedPane ? .trailing : [])
        .sheet(isPresented: $showCoinShop) { CoinShopView() }
        .paneSheet(isPresented: $showCheckout) {
            CheckoutView { bought in
                showCheckout = false
                if reduceMotion { unboxing = bought }
                else { withAnimation { unboxing = bought } }
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
        .alert("Favorite not updated", isPresented: Binding(
            get: { favoriteError != nil },
            set: { if !$0 { favoriteError = nil } }
        )) {
            Button("Retry") { Task { await updateFavorite() } }
            Button("Cancel", role: .cancel) { favoriteError = nil }
        } message: {
            Text(favoriteError ?? "")
        }
        .onAppear {
            let tab = owningTab ?? router.selectedTab
            owningTab = tab
            router.pushedDetail(on: tab)
            viewedAt = Date()
            var props: AnalyticsProps = ["product_id": product.id]
            props.merge(product.tasteProps) { current, _ in current }
            Analytics.track("product_viewed", props)
        }
        .onDisappear {
            if let owningTab { router.poppedDetail(on: owningTab) }
            guard let viewedAt else { return }
            var props: AnalyticsProps = ["product_id": product.id,
                                         "dwell_seconds": Date().timeIntervalSince(viewedAt)]
            props.merge(product.tasteProps) { current, _ in current }
            Analytics.track("product_dwell", props)
        }
    }

    private var paneBackButton: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(.primary.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Spacer()
        }
        .padding(.horizontal, DetailHeroLayout.padding)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// On a short screen (the iPhone Duo's panes, a small phone) a full-width
    /// photo pushed the name, then the spec card, under the buy bar. There the
    /// photo shrinks so the first screen ends on the tags and the specs start
    /// below the bar.
    private var hero: DetailHeroLayout.Hero? {
        guard barTop > visibleTop else { return nil }
        let visible = CGSize(width: visibleWidth, height: barTop - visibleTop)
        return DetailHeroLayout.hero(visible: visible, infoHeight: infoHeight)
    }

    /// Capped in an unfolded pane, the photo keeps the pane's full width and
    /// shows the whole piece on a wash of its own art, rather than a
    /// phone-width photo with empty margins either side.
    private var widensPhoto: Bool { isUnfoldedPane && hero != nil }

    private var photoAspect: CGFloat {
        guard widensPhoto, let hero else { return DetailHeroLayout.photoAspect }
        return DetailHeroLayout.widePhotoAspect(visibleWidth: visibleWidth, photoHeight: hero.photoHeight)
    }

    private var photo: some View {
        RemoteImage(url: product.imageUrl, rarity: product.rarityKind, maxPixelSize: 1400,
                    showsWholePiece: widensPhoto)
            .aspectRatio(photoAspect, contentMode: .fit)
            .frame(maxWidth: widensPhoto ? .infinity : hero.map { $0.photoHeight * DetailHeroLayout.photoAspect },
                   maxHeight: hero?.photoHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(alignment: .topTrailing) {
                favoriteButton.padding(12)
            }
            .overlay(alignment: .topLeading) {
                RarityTag(rarity: product.rarityKind).padding(12)
            }
            .frame(maxWidth: .infinity)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let brand {
                NavigationLink {
                    BrandView(brand: brand)
                } label: {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var favoriteButton: some View {
        Button {
            Task { await updateFavorite() }
        } label: {
            Image(systemName: shop.isFavorite(product.id) ? "heart.fill" : "heart")
                .font(.dcIconM)
                .foregroundStyle(shop.isFavorite(product.id) ? Theme.pink : .white)
                .padding(10)
                .background(.black.opacity(0.35), in: Circle())
        }
        .disabled(updatingFavorite)
        .accessibilityLabel(shop.isFavorite(product.id) ? "Remove from favorites" : "Add to favorites")
    }

    private func updateFavorite() async {
        guard auth.requireAccount("favorite") else { return }
        guard !updatingFavorite else { return }
        updatingFavorite = true
        defer { updatingFavorite = false }
        do {
            try await shop.toggleFavorite(product.id)
            favoriteError = nil
        } catch {
            Haptics.warning()
            favoriteError = error.localizedDescription
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

    @ViewBuilder
    private var completeTheLook: some View {
        let suggestions = shop.complementaryProducts(for: product)
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Complete the look", subtitle: "Picked to style with this")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions) { suggestion in
                            NavigationLink {
                                ProductDetailView(product: suggestion)
                            } label: {
                                ProductCard(product: suggestion,
                                            owned: shop.ownedIds.contains(suggestion.id),
                                            isNew: shop.newDropIds.contains(suggestion.id))
                                    .frame(width: 150)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Complete the look recommendations")
        }
    }

    private var buyBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                priceBlock
                Spacer(minLength: 8)
                purchaseControl
            }
            VStack(spacing: 10) {
                HStack { priceBlock; Spacer() }
                purchaseControl.frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        // In a pane, the page's own background, so the bar meets the fold
        // without a strip of material ending short of the Cart pane. The
        // hairline keeps to the content margins.
        .background(isUnfoldedPane ? AnyShapeStyle(Theme.bg(scheme)) : AnyShapeStyle(.ultraThinMaterial))
        .overlay(alignment: .top) { Divider().padding(.horizontal, isUnfoldedPane ? 16 : 0) }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).minY
        } action: { barTop = $0 }
    }

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Price")
                .font(.dcCaption)
                .foregroundStyle(Theme.subtle(scheme))
            CoinLabel(amount: product.price, size: 20, weight: .heavy)
                .foregroundStyle(Theme.ink(scheme))
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private var purchaseControl: some View {
        if owned {
            Label("In your closet", systemImage: "checkmark.seal.fill")
                .font(.dcBody)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.green.gradient, in: Capsule())
        } else {
            Button {
                // Cart and checkout are account-based, so a guest gets the
                // sign-in sheet here instead of a cart that can't be paid for.
                guard auth.requireAccount("add_to_cart") else { return }
                if inCart {
                    showCheckout = true
                } else {
                    _ = shop.addToCart(product.id)
                    if reduceMotion { addedPulse.toggle() }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { addedPulse.toggle() } }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: inCart ? "creditcard.fill" : "cart.badge.plus")
                    Text(inCart ? "Go to checkout" : "Add to cart")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.dcButton)
                .foregroundStyle(.white)
                .frame(minWidth: 180)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(inCart ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Theme.candy),
                            in: Capsule())
                .scaleEffect(addedPulse ? 1.04 : 1)
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("detailCheckoutButton")
        }
    }
}
