import SwiftUI
import UIKit
import Vision
import CoreImage

// The dressing room composites the avatar from sprites instead of generating a
// fresh AI image per outfit. Each product's studio photo is turned into a
// transparent garment cutout ON DEVICE with Vision foreground segmentation,
// computed once per product and cached in memory + on disk. After that, trying
// on any combination of owned pieces is instant, free, and offline — no
// per-outfit generation, so it scales to any number of users.
final class AvatarCutoutCache: @unchecked Sendable {
    static let shared = AvatarCutoutCache()

    private let mem = NSCache<NSString, UIImage>()
    private let dir: URL
    private let ctx = CIContext()

    private init() {
        mem.countLimit = 200
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = caches.appendingPathComponent("cutouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// A transparent cutout of the product's garment, or nil if segmentation
    /// fails (caller falls back to the flat product image).
    func cutout(for product: Product) async -> UIImage? {
        let key = product.id as NSString
        if let hit = mem.object(forKey: key) { return hit }

        let file = dir.appendingPathComponent("\(product.id).png")
        if let data = try? Data(contentsOf: file), let img = UIImage(data: data) {
            mem.setObject(img, forKey: key)
            return img
        }

        guard let source = await loadSource(product.imageUrl) else { return nil }
        let ctx = self.ctx
        // Vision is heavy — keep it off the main actor.
        let cut = await Task.detached(priority: .userInitiated) {
            AvatarCutoutCache.segment(source, ctx: ctx)
        }.value
        guard let cut else { return nil }

        mem.setObject(cut, forKey: key)
        if let png = cut.pngData() { try? png.write(to: file) }
        return cut
    }

    /// Reuse the grid's decoded image if it's warm; otherwise fetch (URLCache
    /// almost always has it already since the piece was shown in the closet).
    private func loadSource(_ url: String) async -> UIImage? {
        if let hit = ImageMemoryCache.shared.image(for: url) { return hit }
        guard let u = URL(string: url) else { return nil }
        var req = URLRequest(url: u, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        req.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let img = UIImage(data: data) else { return nil }
        return img
    }

    private static func segment(_ image: UIImage, ctx: CIContext) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        guard (try? handler.perform([request])) != nil,
              let result = request.results?.first,
              let buffer = try? result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: true)
        else { return nil }
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let out = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: out)
    }
}

// Where each slot's cutout sits on the avatar canvas (fractions of the frame)
// and its stacking order. Rough by design — the garment cutouts are studio
// shots, so this reads as a stylized paper-doll rather than an anatomical fit.
struct SlotPlacement {
    let z: Double
    let cx: CGFloat   // center x, 0…1
    let cy: CGFloat   // center y, 0…1
    let w: CGFloat    // width, fraction of canvas
    let h: CGFloat    // height, fraction of canvas

    // Back-to-front so layered pieces (outerwear over top, hat over hair) stack
    // the way you'd wear them.
    static let bySlot: [String: SlotPlacement] = [
        "bottom":    .init(z: 10, cx: 0.50, cy: 0.68, w: 0.52, h: 0.44),
        "footwear":  .init(z: 15, cx: 0.50, cy: 0.93, w: 0.40, h: 0.13),
        "top":       .init(z: 20, cx: 0.50, cy: 0.42, w: 0.50, h: 0.34),
        "outerwear": .init(z: 25, cx: 0.50, cy: 0.45, w: 0.64, h: 0.46),
        "accessory": .init(z: 28, cx: 0.28, cy: 0.55, w: 0.24, h: 0.24),
        "bag":       .init(z: 30, cx: 0.80, cy: 0.58, w: 0.30, h: 0.30),
        "jewelry":   .init(z: 33, cx: 0.50, cy: 0.30, w: 0.20, h: 0.12),
        "headwear":  .init(z: 40, cx: 0.50, cy: 0.09, w: 0.36, h: 0.22),
        "eyewear":   .init(z: 42, cx: 0.50, cy: 0.18, w: 0.26, h: 0.09),
    ]
}
