import CryptoKit
import UIKit

// Persistent cache of already-downsampled product art, one JPEG per
// (url, size bucket) pair, in Caches/imagethumbs. Sits below ImageMemoryCache
// so a cold relaunch reads a small pre-shrunk file instead of re-fetching the
// full-size Pollinations shot (still true even though URLCache also holds the
// raw bytes on disk — this skips both the network round trip and the
// full-resolution decode + downsample work every launch).
final class ImageDiskCache: @unchecked Sendable {
    static let shared = ImageDiskCache()

    private let dir: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = caches.appendingPathComponent("imagethumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func fileURL(for url: String, maxPixelSize: CGFloat) -> URL {
        // "v2": thumbnails stored before the watermark trim kept the mark.
        let key = "v2:\(url)@\(Int(maxPixelSize))"
        let digest = SHA256.hash(data: Data(key.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(hash).appendingPathExtension("jpg")
    }

    // Small reads off the fast-path Caches directory; done inline like the
    // rest of the app's on-disk caches (see AvatarCutoutCache) rather than
    // hopping to a dedicated queue.
    func image(for url: String, maxPixelSize: CGFloat) async -> UIImage? {
        let file = fileURL(for: url, maxPixelSize: maxPixelSize)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }

    func store(_ image: UIImage, for url: String, maxPixelSize: CGFloat) {
        let file = fileURL(for: url, maxPixelSize: maxPixelSize)
        Task.detached(priority: .utility) {
            guard let data = image.jpegData(compressionQuality: 0.82) else { return }
            try? data.write(to: file, options: .atomic)
        }
    }
}
