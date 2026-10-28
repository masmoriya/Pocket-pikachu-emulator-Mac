import Foundation
import OSLog

struct SpriteFrame: Decodable, Sendable {
    let id: String
    let index: Int
}

struct AnimationStep: Decodable, Sendable {
    let frame: String
    let duration: TimeInterval
}

struct AnimationClip: Decodable, Sendable {
    let id: String
    let loop: Bool
    let loopStart: Int
    let steps: [AnimationStep]

    var duration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }
}

struct AnimationLibrary: Sendable {
    let width: Int
    let height: Int
    let columns: Int
    let frames: [String: SpriteFrame]
    let clips: [String: AnimationClip]
    let aliases: [String: String]

    static let bundled: AnimationLibrary? = {
        do { return try load(bundle: .main) }
        catch {
            Logger(subsystem: "PocketPikachuWatch", category: "Sprites")
                .error("Cannot load bundled animations: \(error.localizedDescription)")
            return nil
        }
    }()

    static func load(bundle: Bundle) throws -> AnimationLibrary {
        guard let url = bundle.url(forResource: "animations", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> AnimationLibrary {
        struct Manifest: Decodable {
            let version: Int
            let width: Int
            let height: Int
            let columns: Int
            let frames: [SpriteFrame]
            let clips: [AnimationClip]
            let aliases: [String: String]
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        let frameIDs = Set(manifest.frames.map(\.id))
        let clipIDs = Set(manifest.clips.map(\.id))
        guard manifest.version == 1, manifest.width > 0, manifest.height > 0,
              manifest.columns > 0, frameIDs.count == manifest.frames.count,
              clipIDs.count == manifest.clips.count, clipIDs.contains("like"),
              manifest.frames.allSatisfy({ $0.index >= 0 }),
              manifest.aliases.values.allSatisfy({ clipIDs.contains($0) }),
              manifest.clips.allSatisfy({ clip in
                  !clip.steps.isEmpty && clip.steps.indices.contains(clip.loopStart)
                  && clip.steps.allSatisfy {
                      frameIDs.contains($0.frame) && $0.duration.isFinite && $0.duration > 0
                  }
              }) else { throw CocoaError(.fileReadCorruptFile) }
        return AnimationLibrary(
            width: manifest.width, height: manifest.height, columns: manifest.columns,
            frames: Dictionary(uniqueKeysWithValues: manifest.frames.map { ($0.id, $0) }),
            clips: Dictionary(uniqueKeysWithValues: manifest.clips.map { ($0.id, $0) }),
            aliases: manifest.aliases
        )
    }

    func clip(for id: String) -> AnimationClip {
        // The validated manifest always contains the original content idle clip.
        clips[id] ?? clips[aliases[id] ?? "like"] ?? clips["like"]!
    }
}
