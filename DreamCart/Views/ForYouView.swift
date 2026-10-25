import SwiftUI

/// The For You feed as a Tinder-style swipe deck: one hero card up front,
/// the next two peeking behind it. Drag right to add to cart, left to pass.
/// The behind cards rise into place as the front one leaves (driven by drag
/// progress, not a post-hoc animation), so the deck never visibly "jumps"
/// when the top card is actually removed. Mechanics mirror the fleet's other
/// swipe decks (Sideline's BriefingDeck, MahjTrainer's FlashcardDrillView).
struct ForYouView: View {
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isUnfoldedPane) private var isUnfoldedPane

    @State private var drag: CGSize = .zero
    @State private var isFlinging = false
    @State private var crossedThreshold = false
    @State private var acceptedFlash = false
    @State private var showCoinShop = false
    @State private var selectedProduct: ProductWithBrand?
    @State private var didHintSwipe = false
    @AppStorage("dreamcart.hasSwipedForYou") private var hasSwipedDeck = false

    private var products: [ProductWithBrand] { shop.forYouProducts }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                header
                if products.isEmpty {
                    Spacer(minLength: 0)
                    exhausted
                    Spacer(minLength: 0)
                } else {
                    // The deck fills whatever space is left below the header,
                    // measured live (no hardcoded height), so it can never
                    // overrun the header or the buttons. In an unfolded pane
                    // the buttons flank the card instead of sitting under it.
                    GeometryReader { proxy in
                        let layout = DeckLayout.arrangement(in: proxy.size, allowsFlanking: isUnfoldedPane)
                        let region = CGSize(width: proxy.size.width, height: layout.deckHeight)
                        ZStack(alignment: .top) {
                            controls(spacing: layout.controlSpacing, size: region)
                                .position(x: proxy.size.width / 2, y: layout.controlsY)
                            deck(card: layout.card, size: region)
                                .frame(width: region.width, height: region.height)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .reservesFloatingTabBar()
            .background(Theme.bg(scheme))
            .navigationTitle("For You")
            // Beside the other tabs' large titles in a Duo pane; inline on a
            // phone, where the deck needs the height.
            .navigationBarTitleDisplayMode(isUnfoldedPane ? .large : .inline)
            .walletToolbar($showCoinShop)
            .navigationDestination(item: $selectedProduct) { product in
                ProductDetailView(product: product)
            }
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

    // MARK: - Deck

    /// Up to three cards mounted at once: the draggable front card plus two
    /// peeking behind it. Slot 0 is the front; higher slots sit further back.
    /// `card` is pinned to the catalog art's own aspect so scaledToFill never
    /// crops the garment off the edges, and sized below a strip the cards
    /// behind peek into, so on a short screen they never rise into the header.
    private func deck(card: CGSize, size: CGSize) -> some View {
        let visible = Array(products.prefix(DeckLayout.depth).enumerated())
        let cardWidth = card.width, cardHeight = card.height
        return ZStack {
            ForEach(visible.reversed(), id: \.element.id) { slot, product in
                cardView(product, slot: slot, size: CGSize(width: cardWidth, height: cardHeight))
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(scale(forSlot: slot))
                    .offset(y: yOffset(forSlot: slot))
                    .offset(slot == 0 ? drag : .zero)
                    .rotationEffect(slot == 0 ? topRotation : .zero, anchor: .bottom)
                    .zIndex(Double(3 - slot))
                    // Only the front card is touchable; behind cards are
                    // decorative peeks and stay out of VoiceOver's way.
                    .allowsHitTesting(slot == 0)
                    .accessibilityHidden(slot != 0)
                    .gesture(dragGesture(size: size))
                    .onTapGesture {
                        guard slot == 0, !isFlinging, drag == .zero else { return }
                        selectedProduct = product
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, DeckLayout.rise)
        .onAppear { maybeHintSwipe() }
    }

    private func cardView(_ product: ProductWithBrand, slot: Int, size: CGSize) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: product.imageUrl, rarity: product.rarityKind, maxPixelSize: 1400)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.28), .clear, .black.opacity(0.8)],
                           startPoint: .top, endPoint: .bottom)
            cardCopy(product)
            if slot == 0 {
                swipeOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) { RarityTag(rarity: product.rarityKind).padding(16) }
        .overlay(alignment: .topTrailing) { pricePill(product.price).padding(16) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(product.rarityKind.color.opacity(0.55), lineWidth: 2))
        .shadow(color: product.rarityKind.color.opacity(0.25), radius: 22, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.name), \(product.brands?.name ?? "DreamCart"), \(product.rarityKind.label), \(Format.coins(product.price)) coins")
        .accessibilityAction(named: "Pass") { fling(direction: -1, size: size) }
        .accessibilityAction(named: "Add to cart") { fling(direction: 1, size: size) }
    }

    private func pricePill(_ price: Int) -> some View {
        CoinLabel(amount: price, size: 16, weight: .heavy)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.38), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
    }

    private func cardCopy(_ product: ProductWithBrand) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(product.brands?.name.uppercased() ?? "DREAMCART")
                .font(.dcOverline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Text(product.name)
                .font(.dcTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                // A long name on a narrow card shrinks to fit rather than trail off.
                .minimumScaleFactor(0.6)
            // As many whole tags as the card's width holds, never a cut-off one.
            ViewThatFits(in: .horizontal) {
                tagLine(product, count: 3).fixedSize()
                tagLine(product, count: 2).fixedSize()
                tagLine(product, count: 1).lineLimit(1)
            }
            .font(.dcLabel)
            .foregroundStyle(.white.opacity(0.82))
        }
        .padding(20)
    }

    private func tagLine(_ product: ProductWithBrand, count: Int) -> Text {
        Text(product.styleTags.prefix(count).map { "#\($0)" }.joined(separator: "  "))
    }

    /// Corner stamps that fade in with the drag, Tinder-style: cart-green on
    /// a right pull, pass-red on a left pull. Only ever shown on the front card.
    private var swipeOverlay: some View {
        ZStack {
            stamp(acceptedFlash ? "CARTED!" : "ADD", icon: "cart.fill", color: .green, angle: -10)
                .opacity(stampOpacity(forDirection: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            stamp("PASS", icon: "xmark", color: .red, angle: 10)
                .opacity(stampOpacity(forDirection: -1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .padding(20)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, icon: String, color: Color, angle: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.dcButton)
        .foregroundStyle(color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(color, lineWidth: 3))
        .rotationEffect(.degrees(angle))
    }

    private func stampOpacity(forDirection direction: CGFloat) -> Double {
        let travel = drag.width * direction
        return Double(min(1, max(0, travel / 90)))
    }

    private func controls(spacing: CGFloat, size: CGSize) -> some View {
        HStack(spacing: spacing) {
            actionButton("xmark", color: .red, label: "Pass") { fling(direction: -1, size: size) }
            actionButton("cart.badge.plus", color: .green, label: "Add to cart") { fling(direction: 1, size: size) }
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

    // MARK: - Stack geometry

    private func restingScale(_ slot: Int) -> CGFloat { 1 - CGFloat(slot) * 0.05 }
    // Negative: cards behind recede *upward*, so the front card's bottom edge
    // (where the copy lives) stays flush and the controls below never collide
    // with a peeking card poking out underneath.
    private func restingY(_ slot: Int) -> CGFloat { CGFloat(slot) * -DeckLayout.step }

    /// 0 at rest, 1 once the front card has traveled a full swipe. Drives the
    /// cards behind it rising into place as it's dragged (and, later, flung) away.
    private var progress: CGFloat { min(1, abs(drag.width) / 110) }

    private func scale(forSlot slot: Int) -> CGFloat {
        guard slot > 0 else { return 1 }
        return restingScale(slot) + (restingScale(slot - 1) - restingScale(slot)) * progress
    }

    private func yOffset(forSlot slot: Int) -> CGFloat {
        guard slot > 0 else { return 0 }
        return restingY(slot) + (restingY(slot - 1) - restingY(slot)) * progress
    }

    private var topRotation: Angle {
        .degrees(Double(max(-14, min(14, drag.width / 14))))
    }

    private func dismissDistance(_ size: CGSize) -> CGFloat {
        max(90, size.width * 0.30)
    }

    // MARK: - Swipe

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isFlinging else { return }
                drag = value.translation
                // Light tick the moment the drag crosses "let go and it
                // flies" territory, so the threshold is felt, not guessed.
                let past = abs(value.translation.width) > dismissDistance(size)
                if past != crossedThreshold {
                    crossedThreshold = past
                    if past { Haptics.soft() }
                }
            }
            .onEnded { value in
                guard !isFlinging else { return }
                crossedThreshold = false
                let dx = value.translation.width
                let flung = abs(dx) > dismissDistance(size)
                    || abs(value.predictedEndTranslation.width) > size.width * 0.75
                if flung {
                    fling(direction: dx >= 0 ? 1 : -1, size: size)
                } else {
                    animateReset()
                }
            }
    }

    private func animateReset() {
        if reduceMotion { drag = .zero }
        else { withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { drag = .zero } }
    }

    private func maybeHintSwipe() {
        guard !hasSwipedDeck, !didHintSwipe, products.count > 1, !reduceMotion else { return }
        didHintSwipe = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            guard !hasSwipedDeck, !isFlinging, drag == .zero else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) {
                drag = CGSize(width: 48, height: 0)
            }
            try? await Task.sleep(for: .milliseconds(430))
            guard !isFlinging else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                drag = .zero
            }
        }
    }

    /// Throws the front card off (or, under Reduce Motion, commits instantly),
    /// then applies the cart/pass side effect with animation suppressed. By
    /// the time the side effect fires, the card behind has already risen to
    /// the front's resting transform (`progress` is 1), so nothing jumps when
    /// the deck actually reflows.
    private func fling(direction: CGFloat, size: CGSize) {
        guard let product = products.first, !isFlinging else { return }
        isFlinging = true
        hasSwipedDeck = true
        if direction > 0 {
            acceptedFlash = true
            Haptics.success()
        }
        guard !reduceMotion else {
            commit(product, accepted: direction > 0)
            drag = .zero
            isFlinging = false
            return
        }
        let exit = CGSize(width: direction * size.width * 1.6, height: drag.height * 1.1)
        withAnimation(.easeIn(duration: 0.24)) {
            drag = exit
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                commit(product, accepted: direction > 0)
                drag = .zero
                isFlinging = false
            }
        }
    }

    /// The actual add-to-cart / discard side effects, unchanged from before:
    /// `addToCart` records the recommendation acceptance and fires its own
    /// haptic; `dismissRecommendation` persists the pass and fires its own.
    private func commit(_ product: ProductWithBrand, accepted: Bool) {
        let position = products.firstIndex(where: { $0.id == product.id }) ?? 0
        var props: AnalyticsProps = ["product_id": product.id,
                                     "direction": accepted ? "right" : "left", "position": position]
        props.merge(product.tasteProps) { current, _ in current }
        Analytics.track(accepted ? "swipe_like" : "swipe_discard", props)
        if accepted {
            // The cart needs an account; the card stays in the deck so the
            // swipe isn't silently lost while the sign-in sheet is up.
            guard auth.requireAccount("add_to_cart") else {
                acceptedFlash = false
                return
            }
            _ = shop.addToCart(product.id, recommendation: true)
            acceptedFlash = false
        } else {
            shop.dismissRecommendation(product.id)
        }
    }
}
