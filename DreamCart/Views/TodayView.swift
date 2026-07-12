import SwiftUI

struct TodayView: View {
    @Binding var tab: Int
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme

    @State private var showCoinShop = false
    @State private var showSpin = false
    @State private var reward: (title: String, amount: Int, subtitle: String)?
    @State private var claiming = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if shop.loadError != nil {
                        LoadErrorBanner()
                    }
                    dailyCard
                    spinCard
                    if !shop.newDrops.isEmpty { newDropsSection }
                    brandShelves
                    Color.clear.frame(height: 10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .background(Theme.bg(scheme))
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .walletToolbar($showCoinShop)
            .refreshable { await shop.refreshAll() }
            .sheet(isPresented: $showSpin) { SpinView() }
        }
        .overlay {
            if let r = reward {
                RewardOverlay(title: r.title, amount: r.amount, subtitle: r.subtitle) {
                    withAnimation { reward = nil }
                }
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late-night haul"
        }
    }

    // MARK: daily reward

    private var dailyCard: some View {
        let can = shop.me?.canClaimDaily ?? false
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Daily Drop", systemImage: "gift.fill")
                    .font(.dcBody)
                    .foregroundStyle(.white)
                Spacer()
                if let s = shop.me?.streak, s > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(s) day\(s == 1 ? "" : "")")
                    }
                    .font(.dcLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.22), in: Capsule())
                }
            }
            Text(can ? "Your coins are waiting" : "Come back tomorrow")
                .font(.dcTitle)
                .foregroundStyle(.white)
            Text(can ? "Claim today's coins and keep your streak alive."
                     : "You've claimed today. Streak safe. Spin for more below.")
                .font(.dcBodyText)
                .foregroundStyle(.white.opacity(0.85))

            Button {
                Task { await claimDaily() }
            } label: {
                HStack {
                    if claiming { ProgressView().tint(Theme.violet) }
                    else { Text(can ? "Claim now" : "Claimed") }
                }
                .font(.dcButton)
                .foregroundStyle(can ? Theme.violet : Theme.subtle(scheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(can ? Color.white : Color.white.opacity(0.4), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(!can || claiming)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .shadow(color: Theme.pink.opacity(0.3), radius: 16, y: 8)
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
                          actionTitle: "Shop all") { tab = 1 }
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
        .navigationDestination(for: ProductWithBrand.self) { ProductDetailView(product: $0) }
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
        }
    }
}
