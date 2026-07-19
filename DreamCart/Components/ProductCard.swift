import SwiftUI
import UIKit

// Async product image with a shimmering placeholder and rarity-tinted backdrop.
// Images are generated on demand server-side, which can 5xx or time out under
// load — so this loader retries with backoff and offers a tap-to-retry instead
// of silently leaving holes in the grid.
struct RemoteImage: View {
    let url: String
    var rarity: Rarity = .common
    // Pixel cap the source is downsampled to before it's decoded/cached.
    // Grid thumbnails default to a small bucket; hero shots (ForYou,
    // product detail) pass a larger one so they stay sharp full-bleed.
    var maxPixelSize: CGFloat = 700
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
                        .font(.dcIconL)
                    Text("Tap to load")
                        .font(.dcCaption)
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
        // Memory hit: assign outside withAnimation so an already-decoded
        // image never flashes through the shimmer/fade — it's just there.
        if let hit = ImageMemoryCache.shared.image(for: url, maxPixelSize: maxPixelSize) {
            image = hit
            return
        }
        guard let target = URL(string: url) else { failed = true; return }
        image = nil
        // Disk hit: a pre-downsampled thumbnail from a previous launch. Also
        // assigned instantly — it's cached, not freshly generated.
        if let diskHit = await ImageDiskCache.shared.image(for: url, maxPixelSize: maxPixelSize) {
            ImageMemoryCache.shared.set(diskHit, for: url, maxPixelSize: maxPixelSize)
            image = diskHit
            return
        }
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
                guard let decoded = ImageDownsampler.decode(data: data, maxPixelSize: maxPixelSize) else {
                    throw URLError(.cannotDecodeContentData)
                }
                ImageMemoryCache.shared.set(decoded, for: url, maxPixelSize: maxPixelSize)
                ImageDiskCache.shared.store(decoded, for: url, maxPixelSize: maxPixelSize)
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
                .font(.dcBadge)
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
                    .clipped()
                VStack(alignment: .leading) {
                    HStack {
                        RarityTag(rarity: product.rarityKind)
                        Spacer()
                        if isNew {
                            Text("NEW")
                                .font(.dcBadge)
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
                        .font(.dcBadge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                }
                .padding(8)
            }
            // Resolve the image height from the card width. Horizontal shelves
            // only propose a width, so an uncapped aspect-ratio image can report
            // an unstable height and let the copy draw into the next section.
            .aspectRatio(0.82, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brands?.name ?? "")
                    .font(.dcOverline)
                    .foregroundStyle(Theme.subtle(scheme))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    // One line, always: a wrapping brand name ("IRONWOOD
                    // SUPPLY") made this card taller than its shelf siblings
                    // and its name/price bled over the section below.
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(product.name)
                    .font(.dcItem)
                    .foregroundStyle(Theme.ink(scheme))
                    .lineLimit(2, reservesSpace: true)
                CoinLabel(amount: product.price)
                    .foregroundStyle(Theme.ink(scheme))
                    .padding(.top, 1)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let brand = product.brands?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prefix = brand.isEmpty ? product.name : "\(brand), \(product.name)"
        return "\(prefix), \(Format.coins(product.price)) coins, \(product.rarityKind.label)"
    }
}
