import Foundation
import ImageIO
import CoreGraphics

/// Decode only the selected style, and bound crops to about 540 KiB of RGBA pixels.
@MainActor
final class SpriteAtlasLoader {
    static let shared = SpriteAtlasLoader()
    private let cache = NSCache<NSNumber, CGImage>()
    private var atlas: CGImage?
    private var loadedStyle: Bool?

    private init() {
        cache.countLimit = 128
        cache.totalCostLimit = 128 * 36 * 30 * 4
    }

    func image(index: Int, colored: Bool, library: AnimationLibrary) -> CGImage? {
        if loadedStyle != colored {
            cache.removeAllObjects()
            atlas = nil
            loadedStyle = colored
            let name = colored ? "color-atlas" : "mono-atlas"
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
                atlas = CGImageSourceCreateImageAtIndex(source, 0, [
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary)
            }
        }
        let key = NSNumber(value: index)
        if let cached = cache.object(forKey: key) { return cached }
        guard index >= 0, let atlas else { return nil }
        let rect = CGRect(
            x: index % library.columns * library.width,
            y: index / library.columns * library.height,
            width: library.width, height: library.height
        )
        guard rect.maxX <= CGFloat(atlas.width), rect.maxY <= CGFloat(atlas.height),
              let image = atlas.cropping(to: rect) else { return nil }
        cache.setObject(image, forKey: key, cost: library.width * library.height * 4)
        return image
    }
}
