import UIKit

// In-memory decode cache on top of URLCache + ImageDiskCache so grids never
// refetch or re-decode. Keyed by URL + the pixel size the caller downsampled
// to, since a grid thumbnail and a hero shot of the same product are cached
// as distinct entries. NSCache is thread-safe, so the unchecked Sendable is
// sound.
final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 400
        // Cost is tracked in bytes (4 bytes/pixel); this caps decoded image
        // memory well below what a few dozen un-downsampled shots would use.
        cache.totalCostLimit = 120 << 20
    }

    private func key(_ url: String, maxPixelSize: CGFloat) -> NSString {
        "\(url)@\(Int(maxPixelSize))" as NSString
    }

    func image(for url: String, maxPixelSize: CGFloat) -> UIImage? {
        cache.object(forKey: key(url, maxPixelSize: maxPixelSize))
    }

    func set(_ image: UIImage, for url: String, maxPixelSize: CGFloat) {
        let pixelCount = image.size.width * image.scale * image.size.height * image.scale
        let cost = max(Int(pixelCount * 4), 1)
        cache.setObject(image, forKey: key(url, maxPixelSize: maxPixelSize), cost: cost)
    }
}

// Small global gate so a grid of uncached shots trickles requests instead of
// bursting into the generation endpoint's rate limit. Shared by on-screen
// loads (RemoteImage) and the splash-time prefetcher so total in-flight
// requests to Pollinations stay bounded regardless of who's asking.
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
