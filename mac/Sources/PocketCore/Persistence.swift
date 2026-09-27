import Foundation

public struct SavedCompanion: Codable, Sendable {
    public var version = 1
    public var pet: PetState
    public var ledger = UsageLedger()
    public var cursors: [String: UsageCursor]? = [:]
    public init(pet: PetState) { self.pet = pet }
}
public struct CompanionStore {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load(defaultHome: String) throws -> SavedCompanion {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SavedCompanion(pet: PetState(codexHome: defaultHome))
        }
        let saved = try JSONDecoder().decode(SavedCompanion.self, from: Data(contentsOf: url))
        guard saved.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return saved
    }
    public func save(_ state: SavedCompanion) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
