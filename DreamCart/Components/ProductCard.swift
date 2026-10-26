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
    /// Show the whole piece on a blurred wash of the same art, for a frame
    /// wider than the art (the product photo across an unfolded Duo pane),
    /// instead of cropping the garment to fill it.
    var showsWholePiece = false
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        // The backdrop sets the size and the art fills it, so an image whose
        // aspect differs from the frame (the trimmed Pollinations renders)
        // never widens a tile past its column.
        LinearGradient(colors: [rarity.color.opacity(0.16), rarity.color.opacity(0.04)],
                       startPoint: .top, endPoint: .bottom)
        .overlay {
            if isScreenshotMode {
                screenshotArtwork
            } else if let image, showsWholePiece {
                // Color.clear takes the frame exactly, so the art fits it
                // (a ZStack grew to the filled wash and the art filled too).
                Color.clear
                    .background {
                        Image(uiImage: image).resizable().scaledToFill()
                            .blur(radius: 30, opaque: true)
                    }
                    .overlay {
                        // Feathered sides, so the art melts into its wash
                        // instead of ending in a seam either side.
                        Image(uiImage: image).resizable().scaledToFit()
                            .mask {
                                LinearGradient(stops: [.init(color: .clear, location: 0),
                                                       .init(color: .black, location: 0.14),
                                                       .init(color: .black, location: 0.86),
                                                       .init(color: .clear, location: 1)],
                                               startPoint: .leading, endPoint: .trailing)
                            }
                    }
                    .transition(.opacity)
            } else if let image {
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
        .clipped()
        .contentShape(.accessibility, Rectangle())
        .task(id: "\(url)#\(attempt)") { await load() }
    }

    #if DEBUG
    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-DreamCartScreenshot")
    }
    #else
    private var isScreenshotMode: Bool { false }
    #endif

    private var screenshotArtwork: some View {
        let style = Self.screenshotStyle(for: url)
        return ZStack {
            LinearGradient(colors: [style.background, style.foreground],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 220, height: 220)
                .offset(x: 70, y: -90)
            Circle()
                .stroke(.white.opacity(0.24), lineWidth: 2)
                .frame(width: 170, height: 170)
                .offset(x: -76, y: 105)
            Image(systemName: style.icon)
                .font(.system(size: 88, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.16), radius: 12, y: 8)
        }
    }

    private static func screenshotStyle(for value: String) -> (background: Color, foreground: Color, icon: String) {
        let seed = value.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        let styles: [(Color, Color, String)] = [
            (.purple, .pink, "hanger"),
            (.blue, .indigo, "tshirt.fill"),
            (.orange, .pink, "bag.fill"),
            (.teal, .blue, "shoeprints.fill"),
            (.indigo, .purple, "crown.fill"),
            (.pink, .orange, "sparkles"),
        ]
        let selected = styles[seed % styles.count]
        return (selected.0, selected.1, selected.2)
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
                .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: phase)
                .onAppear { phase = 1.4 }
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
                // A narrow tile must never wrap the badge ("RAR / E").
                .fixedSize()
        }
    }
}

// The core browsing tile.
struct ProductCard: View {
    let product: ProductWithBrand
    var owned: Bool = false
    var isNew: Bool = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isUnfoldedPane) private var isUnfoldedPane
    @ScaledMetric(relativeTo: .headline) private var nameHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .headline) private var metadataHeight: CGFloat = 92
    @ScaledMetric(relativeTo: .body) private var priceHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: product.imageUrl, rarity: product.rarityKind)
                    .clipped()
                    // Filled art overflows the tile before the clip, and that
                    // unclipped frame used to widen the card's accessibility
                    // frame (and grow it when the art arrived). The card's
                    // label already names the piece.
                    .accessibilityHidden(true)
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
                                .fixedSize()
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
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
                Text(product.name)
                    .font(.dcItem)
                    .foregroundStyle(Theme.ink(scheme))
                    .lineLimit(2, reservesSpace: true)
                    .truncationMode(.tail)
                    // A pane's whole-card row is narrower than a phone shelf:
                    // shrink a long name before cutting it short.
                    .minimumScaleFactor(isUnfoldedPane ? 0.75 : 1)
                    .frame(maxWidth: .infinity, minHeight: nameHeight, alignment: .topLeading)
                CoinLabel(amount: product.price)
                    .foregroundStyle(Theme.ink(scheme))
                    .frame(height: priceHeight, alignment: .leading)
            }
            .frame(height: metadataHeight, alignment: .topLeading)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        // Filled art is drawn past the tile and clipped. Pin the card's
        // accessibility frame to the tile so it does not widen when the art
        // arrives.
        .contentShape(.accessibility, Rectangle())
    }

    private var accessibilityDescription: String {
        let brand = product.brands?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prefix = brand.isEmpty ? product.name : "\(brand), \(product.name)"
        return "\(prefix), \(Format.coins(product.price)) coins, \(product.rarityKind.label)"
    }
}
