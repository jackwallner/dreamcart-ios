import SwiftUI

struct TodayView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(RouteCoordinator.self) private var router
    @Environment(LocalNotificationCoordinator.self) private var notifications
    @Environment(\.colorScheme) private var scheme

    @State private var showCoinShop = false
    @State private var showSpin = false
    @State private var reward: (title: String, amount: Int, subtitle: String)?
    @State private var claiming = false
    @State private var greetingDate = Date()
    @State private var showNotificationPrimer = false
    @State private var showShop = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if shop.loadError != nil {
                        LoadErrorBanner()
                    }
                    if shop.isLoading && shop.products.isEmpty {
                        TodayLoadingView()
                    } else {
                        dailyCard
                        spinCard
                        if !shop.newDrops.isEmpty { newDropsSection }
                        brandShelves
                    }
                    Color.clear.frame(height: 10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .background(Theme.bg(scheme))
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .walletToolbar($showCoinShop)
            .navigationDestination(for: ProductWithBrand.self) { ProductDetailView(product: $0) }
            .navigationDestination(for: Brand.self) { BrandView(brand: $0) }
            .navigationDestination(isPresented: $showShop) { ShopView() }
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
            .sheet(isPresented: $showSpin) { SpinView() }
            .sheet(isPresented: $showNotificationPrimer) { NotificationPrimerView() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    greetingDate = Date()
                }
            }
        }
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

    // MARK: daily reward

    @ViewBuilder
    private var dailyCard: some View {
        let can = shop.me?.canClaimDaily ?? false
        if can {
            claimableDailyCard
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else {
            claimedDailyChip
                .transition(.move(edge: .top).combined(with: .opacity))
        }
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
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.dcIconM)
            if let streak = shop.me?.streak, streak > 0 {
                Label("\(streak)-day streak", systemImage: "flame.fill")
                    .font(.dcLabel)
            }
            Spacer()
            Text("Claimed")
                .font(.dcLabel)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.22), in: Capsule())
            Text("More tomorrow")
                .font(.dcSub)
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: shop.me?.canClaimDaily)
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

    private var spinCard: some View {
        let can = shop.me?.canSpin ?? false
        return Button { Haptics.tap(); showSpin = true } label: {
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
                    Text(can ? "Your free spin is ready" : "Free spin resets tomorrow")
                        .font(.dcSub)
                        .foregroundStyle(Theme.subtle(scheme))
                }
                Spacer()
                if can {
                    Text("SPIN")
                        .font(.dcLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.candy, in: Capsule())
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.subtle(scheme))
                }
            }
            .padding(16)
            .cardStyle(scheme)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: shelves

    private var newDropsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Just dropped", subtitle: "Fresh today",
                          actionTitle: "Shop all") { router.receive(.shop) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(shop.newDrops) { p in
                        NavigationLink(value: p) {
                            ProductCard(product: p, owned: shop.ownedIds.contains(p.id), isNew: true)
                                .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
                                            .frame(width: 150)
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
