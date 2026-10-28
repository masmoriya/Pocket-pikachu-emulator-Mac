import Foundation

public struct GameSettings: Codable, Equatable, Sendable {
    public enum ClockFormat: String, Codable, CaseIterable, Sendable { case system, twelveHour, twentyFourHour }
    public static let stepRates: [Int64] = [1, 5, 10, 20, 50, 100]
    public var colored = true
    public var clockFormat: ClockFormat = .system
    public var hapticsEnabled = true
    public var showSteps = true
    public var showWatts = true
    public var reducedAnimation = false
    public var stepsPerWatt: Int64 = 1
    public var cycleActivitiesOnTap = true
    public var spriteSize = 100
    public var routineMode: RoutineMode = .free
    public var dailySchedule = DailyRoutine.defaults
    public var selectedActivity: String?
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case colored, clockFormat, hapticsEnabled, showSteps, showWatts, reducedAnimation
        case stepsPerWatt, cycleActivitiesOnTap, spriteSize, routineMode, dailySchedule, selectedActivity
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        colored = try values.decodeIfPresent(Bool.self, forKey: .colored) ?? true
        clockFormat = try values.decodeIfPresent(ClockFormat.self, forKey: .clockFormat) ?? .system
        hapticsEnabled = try values.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        showSteps = try values.decodeIfPresent(Bool.self, forKey: .showSteps) ?? true
        showWatts = try values.decodeIfPresent(Bool.self, forKey: .showWatts) ?? true
        reducedAnimation = try values.decodeIfPresent(Bool.self, forKey: .reducedAnimation) ?? false
        // Existing schema-1 companions retain their original earning rate.
        stepsPerWatt = try values.decodeIfPresent(Int64.self, forKey: .stepsPerWatt) ?? 20
        cycleActivitiesOnTap = try values.decodeIfPresent(Bool.self, forKey: .cycleActivitiesOnTap) ?? true
        spriteSize = try values.decodeIfPresent(Int.self, forKey: .spriteSize) ?? 100
        routineMode = try values.decodeIfPresent(RoutineMode.self, forKey: .routineMode) ?? .free
        dailySchedule = try values.decodeIfPresent([DailyActivity].self, forKey: .dailySchedule) ?? DailyRoutine.defaults
        selectedActivity = try values.decodeIfPresent(String.self, forKey: .selectedActivity)
    }
}
