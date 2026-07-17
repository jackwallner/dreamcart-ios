import UIKit

// Warms the image cache for above-the-fold product art while the splash
// screen is still up, so the shop grid and For You queue have real pixels
// the instant the tabs appear instead of a wall of shimmer. Bounded by the
// same ImageFetchGate the on-screen loaders use (limit 3), so this never
// competes with itself for Pollinations' rate limit — it just fills the gate
// early.
enum ImagePrefetcher {
    /// Default bucket matches the shop/closet grid's thumbnail size.
    static func warmGrid(urls: some Sequence<String>, maxPixelSize: CGFloat = 700) async {
        var seen = Set<String>()
        let ordered = urls.filter { seen.insert($0).inserted }
        await withTaskGroup(of: Void.self) { group in
            for url in ordered {
                group.addTask { await warmOne(url, maxPixelSize: maxPixelSize) }
            }
        }
    }

    private static func warmOne(_ url: String, maxPixelSize: CGFloat) async {
        if ImageMemoryCache.shared.image(for: url, maxPixelSize: maxPixelSize) != nil { return }
        if let diskHit = await ImageDiskCache.shared.image(for: url, maxPixelSize: maxPixelSize) {
            ImageMemoryCache.shared.set(diskHit, for: url, maxPixelSize: maxPixelSize)
            return
        }
        guard let target = URL(string: url) else { return }
        var request = URLRequest(url: target, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        for tryIndex in 0..<3 {
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
                return
            } catch {
                if Task.isCancelled { return }
                if rateLimited {
                    let delay = 3.0 * Double(tryIndex + 1) + Double.random(in: 0...1.5)
                    try? await Task.sleep(for: .seconds(delay))
                } else {
                    // Non-429 failure (timeout, 5xx, bad decode): don't burn
                    // the splash window retrying hard — one short backoff,
                    // then let the grid's own RemoteImage loader take over
                    // on-screen with its fuller retry budget.
                    try? await Task.sleep(for: .seconds(1.0))
                }
                if Task.isCancelled { return }
            }
        }
    }
}
