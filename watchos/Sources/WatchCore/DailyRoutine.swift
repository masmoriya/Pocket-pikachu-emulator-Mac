import Foundation

public struct DailyActivity: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var minute: Int
    public var activity: String
    public init(id: UUID = UUID(), minute: Int, activity: String) {
        self.id = id; self.minute = min(1439, max(0, minute)); self.activity = activity
    }
}

public enum RoutineMode: String, Codable, CaseIterable, Sendable {
    case free, scheduled
    public var label: String { self == .free ? "Free play" : "Daily schedule" }
}

public enum DailyRoutine {
    public static let defaults = [
        DailyActivity(minute: 0, activity: "sleep-front"),
        DailyActivity(minute: 360, activity: "love"),
        DailyActivity(minute: 420, activity: "walk"),
        DailyActivity(minute: 480, activity: "computer"),
        DailyActivity(minute: 660, activity: "sleep-front"),
        DailyActivity(minute: 720, activity: "blocks"),
        DailyActivity(minute: 900, activity: "icecream"),
        DailyActivity(minute: 960, activity: "walk"),
        DailyActivity(minute: 1020, activity: "reading"),
        DailyActivity(minute: 1260, activity: "sleep-front")
    ]

    public static func activity(in entries: [DailyActivity], at date: Date,
                                calendar: Calendar = .current) -> String? {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let ordered = entries.sorted { $0.minute == $1.minute
            ? $0.id.uuidString < $1.id.uuidString : $0.minute < $1.minute }
        return ordered.last { $0.minute <= minute }?.activity ?? ordered.last?.activity
    }

    /// Manual selections stay pinned until Live freely is chosen. Applying the
    /// same schedule repeatedly never records another interaction or restarts it.
    @discardableResult public static func apply(at date: Date, state: inout PetState,
                                                calendar: Calendar = .current) -> Bool {
        guard state.settings.routineMode == .scheduled, state.settings.selectedActivity == nil,
              let activity = activity(in: state.settings.dailySchedule, at: date, calendar: calendar),
              state.currentActivity != activity else { return false }
        state.currentActivity = activity
        state.currentAnimation = activity
        state.lastStateUpdateDate = date
        return true
    }
}
