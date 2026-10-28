import Foundation

/// Read-only presentation data. Health records and game authority stay in the app.
struct PetSnapshot: Codable {
    var date: Date
    var steps: Int?
    var watts: Int64
    var mood: String
    var frameID: String
}

enum SharedSnapshotStore {
    static var groupID: String {
        Bundle.main.object(forInfoDictionaryKey: "PocketAppGroup") as? String ?? "group.com.pocketpikachu.watch"
    }
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("pet-snapshot.json")
    }
    static func read() -> PetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PetSnapshot.self, from: data)
    }
    static func write(_ snapshot: PetSnapshot) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
