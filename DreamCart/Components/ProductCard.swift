import SwiftUI

// Async product image with a shimmering placeholder and rarity-tinted backdrop.
struct RemoteImage: View {
    let url: String
    var rarity: Rarity = .common
    @Environment(\.colorScheme) private var scheme
    @State private var loaded = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [rarity.color.opacity(0.16), rarity.color.opacity(0.04)],
                           startPoint: .top, endPoint: .bottom)
            AsyncImage(url: URL(string: url), transaction: .init(animation: .easeOut(duration: 0.35))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.subtle(scheme).opacity(0.4))
                case .empty:
                    ShimmerView()
                @unknown default:
                    Color.clear
                }
            }
        }
    }
}

struct ShimmerView: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.gray.opacity(0.10), .gray.opacity(0.22), .gray.opacity(0.10)],
                           startPoint: .leading, endPoint: .trailing)
                .offset(x: phase * geo.size.width)
                .onAppear {
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        phase = 1.4
                    }
                }
        }
    }
}

struct RarityTag: View {
    let rarity: Rarity
    var body: some View {
        if rarity != .common {
            Text(rarity.label.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(rarity.color, in: Capsule())
                .shadow(color: rarity.glow ? rarity.color.opacity(0.6) : .clear, radius: 5)
        }
    }
}

// The core browsing tile.
struct ProductCard: View {
    let product: ProductWithBrand
    var owned: Bool = false
    var isNew: Bool = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: product.imageUrl, rarity: product.rarityKind)
                    .aspectRatio(0.82, contentMode: .fill)
                    .clipped()
                VStack(alignment: .leading) {
                    HStack {
                        RarityTag(rarity: product.rarityKind)
                        Spacer()
                        if isNew {
                            Text("NEW")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Theme.pink, in: Capsule())
                        }
                    }
                    Spacer()
                    if owned {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Owned")
                        }
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brands?.name ?? "")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.subtle(scheme))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink(scheme))
                    .lineLimit(1)
                CoinLabel(amount: product.price, size: 14, weight: .heavy)
                    .foregroundStyle(Theme.ink(scheme))
                    .padding(.top, 1)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
    }
}
