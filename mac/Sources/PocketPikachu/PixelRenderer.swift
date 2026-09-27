import AppKit
import PocketCore

/// Cached atlas crops preserve integer pixels at every display scale.
@MainActor final class PixelRenderer {
    static let shared = PixelRenderer()
    private var atlas: [Bool: CGImage] = [:]
    private var images: [String: NSImage] = [:]
    private var bitmaps: [String: NSBitmapImageRep] = [:]
    private var indices: [String: Int] = [:]
    func configure(_ frames: [PixelFrame]) {
        indices = Dictionary(uniqueKeysWithValues: frames.enumerated().map { ($0.element.id, $0.offset) })
        for colored in [false, true] {
            let name = colored ? "color-atlas" : "mono-atlas"
            if let url = AppResources.bundle.url(forResource: name, withExtension: "png"),
               let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) { atlas[colored] = image }
        }
    }
    func opaque(_ frame: PixelFrame, colored: Bool, x: Int, y: Int) -> Bool {
        guard (0..<36).contains(x), (0..<30).contains(y) else { return false }
        let key = "\(frame.id)-\(colored)"
        if bitmaps[key] == nil, let tiff = image(frame, colored: colored).tiffRepresentation {
            bitmaps[key] = NSBitmapImageRep(data: tiff)
        }
        return (bitmaps[key]?.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0
    }
    func image(_ frame: PixelFrame, colored: Bool) -> NSImage {
        let key = "\(frame.id)-\(colored)"
        if let image = images[key] { return image }
        let result: NSImage
        if let index = indices[frame.id], let atlas = atlas[colored],
           let crop = atlas.cropping(to: CGRect(x: index % 16 * 36, y: index / 16 * 30, width: 36, height: 30)) {
            result = NSImage(cgImage: crop, size: NSSize(width: 36, height: 30))
        } else {
            result = NSImage(size: NSSize(width: 36, height: 30), flipped: true) { rect in
                NSColor.labelColor.setFill()
                for pixel in frame.pixels { NSRect(x: pixel % 36, y: pixel / 36, width: 1, height: 1).fill() }
                return true
            }
        }
        images[key] = result
        return result
    }
}
import ImageIO
