import ImageIO
import SwiftUI

/// Reads only the saved frame. The widget never advances an animation or game state.
struct WidgetPetSprite: View {
    let frameID: String
    var colored = true

    var body: some View {
        if let frame = WidgetSpriteAtlas.frame(frameID, colored: colored) {
            Image(decorative: frame, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Text("Pikachu").font(.caption2)
        }
    }
}

@MainActor private enum WidgetSpriteAtlas {
    private struct Manifest: Decodable {
        struct Frame: Decodable {
            let id: String
            let index: Int
        }
        let width: Int
        let height: Int
        let columns: Int
        let frames: [Frame]
    }

    private static let manifest: Manifest? = {
        guard let url = Bundle.main.url(forResource: "animations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }()

    private static let colorAtlas = loadAtlas("color-atlas")
    private static let monoAtlas = loadAtlas("mono-atlas")
    private static let frames: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.countLimit = 24
        return cache
    }()

    private static func loadAtlas(_ name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func frame(_ id: String, colored: Bool) -> CGImage? {
        let key = "\(colored):\(id)" as NSString
        if let cached = frames.object(forKey: key) { return cached }
        guard let manifest, let atlas = colored ? colorAtlas : monoAtlas,
              manifest.width == 36, manifest.height == 30, manifest.columns > 0,
              let index = manifest.frames.first(where: { $0.id == id })?.index,
              index >= 0 else { return nil }
        let rectangle = CGRect(
            x: CGFloat((index % manifest.columns) * manifest.width),
            y: CGFloat((index / manifest.columns) * manifest.height),
            width: CGFloat(manifest.width),
            height: CGFloat(manifest.height)
        )
        guard rectangle.maxX <= CGFloat(atlas.width), rectangle.maxY <= CGFloat(atlas.height) else {
            return nil
        }
        guard let frame = atlas.cropping(to: rectangle) else { return nil }
        frames.setObject(frame, forKey: key)
        return frame
    }
}
