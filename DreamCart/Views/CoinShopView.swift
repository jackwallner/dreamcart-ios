import SwiftUI

struct CoinShopView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(StoreController.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var buying: String? = nil
    @State private var reward: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    balanceHeader
                    ForEach(CoinPack.all) { pack in
                        packCard(pack)
                    }
                    footer
                }
                .padding(16)
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Get Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .overlay {
            if let r = reward {
                RewardOverlay(title: "Coins added", amount: r,
                              subtitle: "Go build something you love.") {
                    withAnimation { reward = nil }
                }
            }
        }
    }

    private var balanceHeader: some View {
        VStack(spacing: 6) {
            Text("Your balance")
                .font(.dcSub)
                .foregroundStyle(.white.opacity(0.85))
            CoinLabel(amount: shop.coins, size: 30)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Theme.candy, in: RoundedRectangle(cornerRadius: Theme.corner))
    }

    private func packCard(_ pack: CoinPack) -> some View {
        Button {
            Task { await buy(pack) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.goldGradient).frame(width: 58, height: 58)
                    Image(systemName: coinIcon(pack))
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(pack.title)
                            .font(.dcCard)
                            .foregroundStyle(Theme.ink(scheme))
                        if let badge = pack.badge {
                            Text(badge)
                                .font(.dcBadge)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.pink, in: Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        CoinIcon(size: 14)
                        Text("\(Format.coins(pack.coins)) coins")
                            .font(.dcBody)
                            .foregroundStyle(Theme.ink(scheme))
                    }
                    Text(pack.blurb)
                        .font(.dcSub)
                        .foregroundStyle(Theme.subtle(scheme))
                }
                Spacer()
                if buying == pack.productId {
                    ProgressView()
                } else {
                    Text(store.price(for: pack))
                        .font(.dcPrice)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.candy, in: Capsule())
                }
            }
            .padding(14)
            .cardStyle(scheme)
        }
        .buttonStyle(PressableStyle())
        .disabled(buying != nil)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Coins are for use inside DreamCart only and have no cash value. All items and delivery are virtual.")
                .font(.dcCaption)
                .foregroundStyle(Theme.subtle(scheme))
                .multilineTextAlignment(.center)
            Button("Restore Purchases") { Task { await store.restore(); await shop.reconcilePurchases() } }
                .font(.dcLabel)
                .foregroundStyle(Theme.violet)
        }
        .padding(.top, 6)
    }

    private func coinIcon(_ pack: CoinPack) -> String {
        switch pack.title {
        case "Pocket": return "bag.fill"
        case "Bag": return "handbag.fill"
        case "Haul": return "cart.fill"
        case "Spree": return "sparkles"
        default: return "crown.fill"
        }
    }

    private func buy(_ pack: CoinPack) async {
        buying = pack.productId
        defer { buying = nil }
        let before = shop.coins
        let ok = await store.purchase(pack)
        if ok {
            await shop.reconcilePurchases()
            let gained = shop.coins - before
            if gained > 0 { withAnimation { reward = gained } }
        }
    }
}
