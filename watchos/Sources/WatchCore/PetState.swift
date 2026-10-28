import Foundation

public enum PetMood: String, Codable, CaseIterable, Sendable {
    case away, mad, neutral, like, love
    public init(points: Int64) {
        self = points <= -1500 ? .away : points <= -500 ? .mad
            : points <= 1500 ? .neutral : points <= 3000 ? .like : .love
    }
    public var animation: String { self == .away ? "left" : rawValue }
    public var label: String {
        switch self {
        case .away: "Away"
        case .mad: "Upset"
        case .neutral: "Neutral"
        case .like: "Likes you"
        case .love: "Loves you"
        }
    }
}

public struct GameSettings: Codable, Equatable, Sendable {
    public enum ClockFormat: String, Codable, CaseIterable, Sendable { case system, twelveHour, twentyFourHour }
    public var colored = true
    public var clockFormat: ClockFormat = .system
    public var hapticsEnabled = true
    public var showSteps = true
    public var showWatts = true
    public var reducedAnimation = false
    public init() {}
}

public struct WattTransaction: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case walking, gift }
    public var id: String
    public var timestamp: Date
    public var type: Kind
    public var amount: Int64
    public var resultingBalance: Int64
    public var relatedActivity: String
}

public struct PetInteraction: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var activity: String
}

public struct PetState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion = currentSchemaVersion
    public var friendshipPoints: Int64 = 0
    public var friendshipLevel: Int { PetMood.allCases.firstIndex(of: mood) ?? 2 }
    public var mood: PetMood { PetMood(points: friendshipPoints) }
    public var currentActivity = "idle"
    public var currentAnimation = "neutral"
    public var wattsBalance: Int64 = 50
    public var lifetimeWattsEarned: Int64 = 0
    public var lifetimeWattsSpent: Int64 = 0
    public var lifetimeStepsCredited: Int64 = 0
    public var stepRemainder: Int64 = 0
    public var lastStepSyncDate: Date?
    public var lastInteractionDate: Date
    public var lastStateUpdateDate: Date
    public var lastGiftDate: Date?
    public var createdAt: Date
    public var unlockedAnimations: [String] = []
    public var settings = GameSettings()
    public var transactions: [WattTransaction] = []
    public var interactions: [PetInteraction] = []
    public var recentGiftRequestIDs: [String] = []
    public var reconciliation = StepLedger()

    public init(now: Date) {
        createdAt = now
        lastInteractionDate = now
        lastStateUpdateDate = now
    }
}
