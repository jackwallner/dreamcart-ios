import SwiftUI

struct TodayView: View {
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    @Environment(LocalNotificationCoordinator.self) private var notifications
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isUnfoldedPane) private var isUnfoldedPane
    @Environment(\.floatingTabBarTop) private var barTop
    /// ProductCard's caption block (8 pt gap and the 92 pt metadata frame).
    @ScaledMetric(relativeTo: .headline) private var cardCaption: CGFloat = 100

    @State private var showCoinShop = false
    @State private var showSpin = false
    @State private var reward: (title: String, amount: Int, subtitle: String)?
    @State private var claiming = false
    @State private var greetingDate = Date()
    @State private var showNotificationPrimer = false
    @State private var showShop = false
    @State private var isAtRest = true
    /// The Just dropped shelf's window frame with the page at rest.
    @State private var shelfFrame: CGRect = .zero

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    if shop.loadError != nil {
                        LoadErrorBanner()
                    }
                    if shop.isLoading && shop.products.isEmpty {
                        TodayLoadingView()
                    } else {
                        if isScreenshotMode {
                            EmptyView()
                        } else if usesPaneDailyRow {
                            paneDailyRow
                        } else {
                            dailyCard
                            spinCard
                        }
                        if !shop.newDrops.isEmpty { newDropsSection }
                        brandShelves
                    }
                    Color.clear.frame(height: 10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .tracksScrollRest($isAtRest)
            .reservesFloatingTabBar()
            .background(Theme.bg(scheme))
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .walletToolbar($showCoinShop)
            .navigationDestination(for: ProductWithBrand.self) { ProductDetailView(product: $0) }
            .navigationDestination(for: Brand.self) { BrandView(brand: $0) }
            .navigationDestination(isPresented: $showShop) { ShopView() }
            #if DEBUG
            .navigationDestination(item: Bindable(DuoTour.shared).product) { ProductDetailView(product: $0) }
            .onChange(of: DuoTour.shared.showShop) { _, open in showShop = open }
            .onChange(of: DuoTour.shared.coins) { _, open in showCoinShop = open }
            #endif
            .refreshable { await shop.refreshAll() }
            .onChange(of: router.presentedRoute) { _, route in
                guard route == .shop else { return }
                showShop = true
                _ = router.consumePresentedRoute()
            }
            .onAppear {
                guard router.presentedRoute == .shop else { return }
                showShop = true
                _ = router.consumePresentedRoute()
            }
            .sheet(isPresented: $showNotificationPrimer) { NotificationPrimerView() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    greetingDate = Date()
                }
            }
        }
        // Outside the stack, so unfolded it covers the whole Today pane.
        .paneSheet(isPresented: $showSpin) { SpinView() }
        #if DEBUG
        .onChange(of: DuoTour.shared.spin) { _, open in showSpin = open }
        #endif
        .overlay {
            if let r = reward {
                RewardOverlay(title: r.title, amount: r.amount, subtitle: r.subtitle) {
                    withAnimation { reward = nil }
                    if notifications.shouldPresentPrimer { showNotificationPrimer = true }
                }
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: greetingDate)
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late-night haul"
        }
    }

    private var isScreenshotMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-DreamCartScreenshot")
        #else
        return false
        #endif
    }

    // MARK: daily reward

    @ViewBuilder
    private var dailyCard: some View {
        let can = shop.me?.canClaimDaily ?? false
        if auth.isGuest {
            guestCoinsCard
        } else if can {
            claimableDailyCard
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else {
            claimedDailyChip
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Guests browse the whole catalog, but coins belong to an account, so the
    /// daily drop and the wheel collapse into one invitation to sign in.
    private var guestCoinsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            dailyDropLabel
            Text("Coins, cart and closet")
                .font(.dcTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Browse as long as you like. Sign in when you want to claim daily coins, spin the wheel and keep what you buy.")
                .font(.dcBodyText)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                auth.requireAccount("daily_drop")
            } label: {
                Text("Sign in")
                    .font(.dcButton)
                    .foregroundStyle(Theme.violet)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .shadow(color: Theme.pink.opacity(0.3), radius: 16, y: 8)
    }

    private var claimableDailyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack { dailyDropLabel; Spacer(); streakLabel }
                VStack(alignment: .leading, spacing: 10) { dailyDropLabel; streakLabel }
            }
            Text("Your coins are waiting")
                .font(.dcTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Claim today's coins and keep your streak alive.")
                .font(.dcBodyText)
                .foregroundStyle(.white.opacity(0.85))

            Button {
                Task { await claimDaily() }
            } label: {
                HStack {
                    if claiming { ProgressView().tint(Theme.violet) }
                    else { Text("Claim now") }
                }
                .font(.dcButton)
                .foregroundStyle(Theme.violet)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(claiming)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .shadow(color: Theme.pink.opacity(0.3), radius: 16, y: 8)
    }

    private var dailyDropLabel: some View {
        Label("Daily Drop", systemImage: "gift.fill")
            .font(.dcBody)
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var streakLabel: some View {
        if let streak = shop.me?.streak, streak > 0 {
            Label("\(streak) day\(streak == 1 ? "" : "s")", systemImage: "flame.fill")
                .font(.dcLabel)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.22), in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var claimedDailyChip: some View {
        // A narrow column (the folded Duo, a Duo pane) keeps the claim and the
        // streak whole and drops the hint rather than cutting all three.
        ViewThatFits(in: .horizontal) {
            claimedDailyRow(showsHint: true)
            claimedDailyRow(showsHint: false)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: shop.me?.canClaimDaily)
    }

    private func claimedDailyRow(showsHint: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.dcIconM)
            Text("Daily claimed")
                .font(.dcLabel)
                .lineLimit(1)
            if let streak = shop.me?.streak, streak > 0 {
                // Just the flame + number so it never wraps or crowds the row.
                Label("\(streak)", systemImage: "flame.fill")
                    .font(.dcLabel)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.22), in: Capsule())
            }
            Spacer(minLength: 6)
            if showsHint {
                Text("More tomorrow")
                    .font(.dcSub)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }

    /// In an unfolded pane the claimed drop and the wheel sit side by side as
    /// two short tiles, using the pane's width so the first screen still
    /// reaches a whole row of drops. A claim still waiting keeps its full card.
    private var usesPaneDailyRow: Bool {
        guard isUnfoldedPane, !auth.isGuest, let me = shop.me else { return false }
        return !me.canClaimDaily
    }

    @ViewBuilder
    private var paneDailyRow: some View {
        let streak = shop.me?.streak ?? 0
        let canSpin = shop.me?.canSpin ?? false
        HStack(spacing: 12) {
            paneTile(icon: "checkmark.seal.fill", title: "Daily claimed",
                     detail: streak > 0 ? "\(streak)-day streak" : "More tomorrow", onCandy: true)
                .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            Button { Haptics.tap(); showSpin = true } label: {
                paneTile(icon: "dial.medium.fill", title: canSpin ? "Spin the wheel" : "Spin used",
                         detail: canSpin ? "Free spin ready" : "Resets tomorrow", onCandy: false)
                    .cardStyle(scheme)
            }
            .buttonStyle(PressableStyle())
            .disabled(!canSpin)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func paneTile(icon: String, title: String, detail: String, onCandy: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(onCandy ? AnyShapeStyle(Color.white.opacity(0.22)) : AnyShapeStyle(Theme.goldGradient))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.dcIconS.weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.dcLabel)
                    .foregroundStyle(onCandy ? .white : Theme.ink(scheme))
                Text(detail)
                    .font(.dcSub)
                    .foregroundStyle(onCandy ? .white.opacity(0.85) : Theme.subtle(scheme))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func claimDaily() async {
        claiming = true
        defer { claiming = false }
        if let r = await shop.claimDaily(), r.ok, let g = r.granted {
            Haptics.celebrate()
            let sub = (r.weeklyBonus ?? false)
                ? "Weekly bonus! Streak \(r.streak ?? 0). See you tomorrow."
                : "Streak \(r.streak ?? 0) days. Come back tomorrow for more."
            withAnimation { reward = ("Daily Drop claimed", g, sub) }
        }
    }

    // MARK: spin

    @ViewBuilder
    private var spinCard: some View {
        if auth.isGuest {
            // Folded into guestCoinsCard above.
            EmptyView()
        } else if shop.me?.canSpin ?? false {
            spinCardReady
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else {
            spinUsedChip
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var spinCardReady: some View {
        Button { Haptics.tap(); showSpin = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.goldGradient).frame(width: 54, height: 54)
                    Image(systemName: "dial.medium.fill")
                        .font(.dcIconL)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Spin the wheel")
                        .font(.dcCard)
                        .foregroundStyle(Theme.ink(scheme))
                    Text("Your free spin is ready")
                        .font(.dcSub)
                        .foregroundStyle(Theme.subtle(scheme))
                }
                Spacer()
                Text("SPIN")
                    .font(.dcLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.candy, in: Capsule())
            }
            .padding(16)
            .cardStyle(scheme)
        }
        .buttonStyle(PressableStyle())
    }

    // Once the free spin is used it collapses to a slim resets-tomorrow chip,
    // matching the claimed daily drop so the top of Today stays calm.
    private var spinUsedChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "dial.medium.fill")
                .font(.dcIconM)
                .foregroundStyle(Theme.gold)
            Text("Spin used")
                .font(.dcLabel)
                .foregroundStyle(Theme.ink(scheme))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("Resets tomorrow")
                .font(.dcSub)
                .foregroundStyle(Theme.subtle(scheme))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .cardStyle(scheme)
    }

    // MARK: shelves

    private let sectionSpacing: CGFloat = 20

    /// In an unfolded pane, Just dropped fills the content width with whole
    /// cards sized to rest above the tab bar (no card cut at the fold or
    /// against the bar). Every shelf then uses that card width.
    private var firstRow: FirstScreenRow.Row? {
        guard isUnfoldedPane, barTop > shelfFrame.minY, shelfFrame.minY > 0 else { return nil }
        return FirstScreenRow.row(width: shelfFrame.width, room: barTop - shelfFrame.minY,
                                  caption: cardCaption)
    }

    private var cardWidth: CGFloat { firstRow?.tileWidth ?? 150 }

    private var newDropsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Just dropped", subtitle: "Fresh today",
                          actionTitle: isScreenshotMode ? nil : "Shop all") { router.receive(.shop) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: FirstScreenRow.spacing) {
                    ForEach(shop.newDrops) { p in
                        NavigationLink(value: p) {
                            ProductCard(product: p, owned: shop.ownedIds.contains(p.id), isNew: true)
                                .frame(width: cardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // In a pane the space below the shelf runs down to the tab bar,
            // so the brand shelves after it start below the bar, not cut
            // against it.
            .padding(.bottom, firstRow.map { barTop - shelfFrame.minY - sectionSpacing + 8 - $0.tileHeight } ?? 0)
            .onRestingFrame(isAtRest: isAtRest) { shelfFrame = $0 }
        }
        .id("new-drops")
    }

    private var brandShelves: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(shop.brands.prefix(4)) { brand in
                let items = shop.products(brandId: brand.id).prefix(6)
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(brand.name)
                                    .font(.dcSection)
                                    .foregroundStyle(Theme.ink(scheme))
                                Text(brand.tagline)
                                    .font(.dcSub)
                                    .foregroundStyle(Color(hex: brand.accentHex))
                            }
                            Spacer()
                            NavigationLink {
                                BrandView(brand: brand)
                            } label: {
                                Text("See all")
                                    .font(.dcLabel)
                                    .foregroundStyle(Theme.violet)
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(items)) { p in
                                    NavigationLink(value: p) {
                                        ProductCard(product: p, owned: shop.ownedIds.contains(p.id))
                                            .frame(width: cardWidth)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            if shop.brands.count > 4 {
                Button("See all brands") { router.receive(.shop) }
                    .font(.dcButton)
                    .foregroundStyle(Theme.violet)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .cardStyle(scheme)
            }
        }
    }
}

private struct TodayLoadingView: View {
    var body: some View {
        VStack(spacing: 22) {
            ProgressView("Loading today's drops…")
                .font(.dcBody)
                .padding(.vertical, 36)
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    ShimmerView().frame(width: 150, height: 24).clipShape(Capsule())
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            ShimmerView()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(0.72, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner))
                        }
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }
}
