import ImageIO
import UIKit

// Decodes remote image bytes straight to display size via CGImageSource,
// instead of UIImage(data:) full decode + a separate resize pass. This is
// what keeps a grid of Pollinations shots (often several megapixels) cheap
// to decode and light to hold in memory.
enum ImageDownsampler {
    static func decode(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1),
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        let kept = thumbnail.cropping(to: unmarkedRect(width: thumbnail.width, height: thumbnail.height))
        return UIImage(cgImage: kept ?? thumbnail)
    }

    /// Share of the height trimmed off the bottom. Pollinations stamps its
    /// "pollinations.ai" mark in the bottom-right corner (about 3.5% of the
    /// height, despite `nologo=true` on keyless requests); every view fills
    /// its frame from the image, so losing the strip costs nothing.
    static let watermarkBand = 0.06

    /// The part of a `width` x `height` image kept above the watermark band.
    static func unmarkedRect(width: Int, height: Int) -> CGRect {
        let trimmed = Int((Double(height) * watermarkBand).rounded(.up))
        return CGRect(x: 0, y: 0, width: width, height: max(height - trimmed, 1))
    }
}
