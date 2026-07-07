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
