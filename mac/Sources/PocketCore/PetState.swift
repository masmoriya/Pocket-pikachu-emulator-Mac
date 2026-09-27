import Foundation

public enum Friendship: String, Codable, CaseIterable, Sendable {
    case love, like, neutral, mad, away
    public var label: String {
        switch self {
        case .love: return "Loves you"
        case .like: return "Likes you"
        case .neutral: return "Neutral"
        case .mad: return "Upset"
        case .away: return "Away"
        }
    }
    public var idle: String {
        switch self { case .love: return "love"; case .like: return "like"
        case .neutral: return "neutral"; case .mad: return "mad"; case .away: return "left" }
    }
}
public struct Progression: Codable, Equatable, Sendable {
    public var tokens: Int64 = 0
    public var steps: Int64 = 0
    public var watts: Int64 = 50
    public var tokensPerStep: Int64 = 1000
    public var fractionalStep: Double = 0
    public var stepsTowardWatt: Int64 = 0
    public init() {}
    public mutating func award(_ count: Int64) {
        guard count > 0 else { return }
        tokens += count
        let earned = fractionalStep + Double(count) / Double(max(1, tokensPerStep))
        let whole = Int64(earned.rounded(.down))
        fractionalStep = earned - Double(whole)
        steps += whole
        watts += (stepsTowardWatt + whole) / 20
        stepsTowardWatt = (stepsTowardWatt + whole) % 20
    }
    public mutating func spend(_ amount: Int64) -> Bool {
        guard amount >= 0, amount <= 999, amount <= watts else { return false }
        watts -= amount
        return true
    }
}
public enum MenuBarStyle: String, Codable, CaseIterable, Sendable {
    case paw, color, monochrome
    public var label: String {
        switch self {
        case .paw: return "Paw print"
        case .color: return "Pikachu · color"
        case .monochrome: return "Pikachu · monochrome"
        }
    }
}

public struct PetState: Codable, Sendable {
    // Optional so existing saved companions decode without a migration.
    public var menuBarStyle: MenuBarStyle? = nil
    public var menuBarOnly: Bool? = nil
    public var friendship: Friendship = .love
    public var selectedActivity: String? = nil
    // Nil preserves a smooth migration for existing saved state; new installs cycle by default.
    public var cycleActivitiesOnClick: Bool? = nil
    public var progression = Progression()
    public var colored = true
    public var shell = false
    public var alwaysOnTop = false
    public var scale = 5
    public var codexHome: String
    public var positions: [String: [Double]] = [:]
    public var lastInteraction: Date = .now
    public init(codexHome: String) { self.codexHome = codexHome }
}
public enum PetBehavior {
    public static func crossedMilestone(from previous: Int64, to current: Int64) -> Int64? {
        var milestone: Int64 = 1_000
        var crossed: Int64?
        while milestone <= current {
            if milestone > previous { crossed = milestone }
            guard milestone <= Int64.max / 10 else { break }
            milestone *= 10
        }
        return crossed
    }
    public static func restingActivity(state: PetState, now: Date) -> String? {
        guard state.selectedActivity == nil else { return nil }
        let idle = now.timeIntervalSince(state.lastInteraction)
        if idle >= 1800 { return "sleep-front" }
        if idle >= 900 { return "reading" }
        return nil
    }
    // Original gift bands and probabilities. Correct the source's accidental 899 gap.
    public static func gift(amount: Int64, friendship: Friendship, roll: Int) -> String {
        if amount == 0 { return "tongue" }
        if amount < 100 { return "yawn" }
        if amount < 300 { return "happy" }
        if amount < 400 { return roll >= 5 ? "hearts" : "flip" }
        if amount < 500 {
            if roll <= 4 || friendship == .mad { return "hearts" }
            return roll <= 8 ? "flip" : "letter"
        }
        if amount < 700 { return roll <= 3 ? "hearts" : roll <= 6 ? "flip" : "letter" }
        if amount < 800 { return roll <= 4 ? "ball" : roll <= 8 ? "diving" : "flying" }
        if amount < 900 { return roll <= 3 ? "piano" : roll <= 6 ? "flying" : roll <= 8 ? "diving" : "ball" }
        return roll <= 2 ? "piano" : roll <= 4 ? "flying" : roll <= 6 ? "diving" : roll <= 8 ? "ball" : "horn"
    }
}
