import Foundation

/// Read-only presentation data. Health records and game authority stay in the app.
struct PetSnapshot: Codable, Equatable {
    var date: Date
    var steps: Int?
    var watts: Int64
    var mood: String
    var frameID: String
    // Optional additions keep snapshots written by earlier versions readable.
    var dailyStepGoal: Int? = nil
    var colored: Bool? = nil

    func currentSteps(at date: Date, calendar: Calendar = .current) -> Int? {
        guard calendar.isDate(self.date, inSameDayAs: date), let steps else { return nil }
        return max(0, steps)
    }

    func goalProgress(at date: Date, calendar: Calendar = .current) -> Double? {
        guard let steps = currentSteps(at: date, calendar: calendar),
              let dailyStepGoal, dailyStepGoal > 0 else { return nil }
        return min(1, Double(steps) / Double(dailyStepGoal))
    }
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
