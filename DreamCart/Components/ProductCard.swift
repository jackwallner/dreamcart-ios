import SwiftUI
import UIKit

// In-memory decode cache on top of URLCache so grids never refetch or re-decode.
// NSCache is thread-safe, so the unchecked Sendable is sound.
final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 400 }
    func image(for url: String) -> UIImage? { cache.object(forKey: url as NSString) }
    func set(_ image: UIImage, for url: String) { cache.setObject(image, forKey: url as NSString) }
}

// Async product image with a shimmering placeholder and rarity-tinted backdrop.
// Images are generated on demand server-side, which can 5xx or time out under
// load — so this loader retries with backoff and offers a tap-to-retry instead
// of silently leaving holes in the grid.
struct RemoteImage: View {
    let url: String
    var rarity: Rarity = .common
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [rarity.color.opacity(0.16), rarity.color.opacity(0.04)],
                           startPoint: .top, endPoint: .bottom)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .transition(.opacity)
            } else if failed {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 22, weight: .semibold))
                    Text("Tap to load")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Theme.subtle(scheme).opacity(0.6))
                .contentShape(Rectangle())
                .onTapGesture { failed = false; attempt += 1 }
            } else {
                ShimmerView()
            }
        }
        .task(id: "\(url)#\(attempt)") { await load() }
    }

    private func load() async {
        if let hit = ImageMemoryCache.shared.image(for: url) { image = hit; return }
        guard let target = URL(string: url) else { failed = true; return }
        image = nil
        var request = URLRequest(url: target, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        for tryIndex in 0..<5 {
            var rateLimited = false
            do {
                await ImageFetchGate.shared.acquire()
                defer { Task { await ImageFetchGate.shared.release() } }
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    rateLimited = http.statusCode == 429
                    throw URLError(.badServerResponse)
                }
                guard let decoded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                ImageMemoryCache.shared.set(decoded, for: url)
                withAnimation(.easeOut(duration: 0.3)) { image = decoded }
                return
            } catch {
                if Task.isCancelled { return }
                // The endpoint 429s on bursts and only renders uncached shots
                // slowly — wait it out (cached renders return instantly later).
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let base = rateLimited ? 3.0 : 1.2
                let delay = base * Double(tryIndex + 1) + Double.random(in: 0...1.5)
                try? await Task.sleep(for: .seconds(delay))
                if Task.isCancelled { return }
            }
        }
        failed = true
    }
}

// Small global gate so a grid of uncached shots trickles requests instead of
// bursting into the generation endpoint's rate limit.
actor ImageFetchGate {
    static let shared = ImageFetchGate()
    private let limit = 3
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if active < limit { active += 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty { active -= 1 }
        else { waiters.removeFirst().resume() }
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
                .font(.system(size: 9, weight: .black))
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
                                .font(.system(size: 9, weight: .black))
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
                        .font(.system(size: 10, weight: .bold))
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.subtle(scheme))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
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
