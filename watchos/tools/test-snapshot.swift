import Foundation

@main
struct SnapshotRegression {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // DST starts on this day: calendar rollover must not assume 24 hours.
        let morning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 8))!
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: morning))!
        var snapshot = PetSnapshot(date: morning, steps: 3000, watts: 50,
                                   mood: "Loves you", frameID: "standBasic.stand",
                                   dailyStepGoal: 6000, colored: false)
        precondition(snapshot.goalProgress(at: morning, calendar: calendar) == 0.5)
        precondition(snapshot.currentSteps(at: midnight, calendar: calendar) == nil)
        precondition(snapshot.goalProgress(at: midnight, calendar: calendar) == nil)
        precondition(midnight.timeIntervalSince(calendar.startOfDay(for: morning)) == 23 * 3600)
        snapshot.steps = 9000
        precondition(snapshot.goalProgress(at: morning, calendar: calendar) == 1)
        snapshot.steps = -1
        precondition(snapshot.goalProgress(at: morning, calendar: calendar) == 0)
        snapshot.steps = nil
        precondition(snapshot.goalProgress(at: morning, calendar: calendar) == nil)
        snapshot.steps = 3000
        snapshot.dailyStepGoal = 0
        precondition(snapshot.goalProgress(at: morning, calendar: calendar) == nil)
        snapshot.dailyStepGoal = 6000
        let data = try JSONEncoder().encode(snapshot)
        let roundTrip = try JSONDecoder().decode(PetSnapshot.self, from: data)
        precondition(roundTrip == snapshot)
        var legacy = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        legacy.removeValue(forKey: "dailyStepGoal")
        legacy.removeValue(forKey: "colored")
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(PetSnapshot.self, from: legacyData)
        precondition(decoded.dailyStepGoal == nil && decoded.colored == nil)
        precondition(decoded.steps == snapshot.steps && decoded.frameID == snapshot.frameID)
        print("Snapshot regression passed: progress bounds, missing data, DST rollover, round trip and legacy decoding.")
    }
}
