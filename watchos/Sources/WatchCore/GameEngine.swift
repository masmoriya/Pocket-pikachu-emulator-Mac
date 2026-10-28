import Foundation

public enum GameError: Error, Equatable {
    case invalidAmount, insufficientWatts, duplicateRequest, giftDebounced, invalidStepWindow, invalidSample
}

public enum GameEngine {
    public static let historyLimit = 200
    public static let giftDebounce: TimeInterval = 1

    // Free activities intentionally preserve friendship: the source defines gifts,
    // game losses and inactivity, but no arbitrary per-tap friendship reward.
    public static func interact(activity: String, now: Date, state: inout PetState) {
        state.currentActivity = activity
        state.currentAnimation = activity == "idle" ? state.mood.animation : activity
        state.lastInteractionDate = now
        state.lastStateUpdateDate = now
        state.interactions.append(PetInteraction(timestamp: now, activity: activity))
        state.interactions = Array(state.interactions.suffix(historyLimit))
        if !state.unlockedAnimations.contains(state.currentAnimation) {
            state.unlockedAnimations.append(state.currentAnimation)
        }
    }

    public static func giveGift(amount: Int64, requestID: String, roll: Int,
                                now: Date, state: inout PetState) throws {
        guard !requestID.isEmpty, !state.recentGiftRequestIDs.contains(requestID) else {
            throw GameError.duplicateRequest
        }
        guard (0...999).contains(amount) else { throw GameError.invalidAmount }
        guard amount <= state.wattsBalance else { throw GameError.insufficientWatts }
        if let last = state.lastGiftDate, now.timeIntervalSince(last) < giftDebounce {
            throw GameError.giftDebounced
        }
        let animation = giftAnimation(amount: amount, mood: state.mood, roll: roll)
        state.wattsBalance -= amount
        state.lifetimeWattsSpent += amount
        state.friendshipPoints += amount == 0 ? -100 : amount
        state.lastGiftDate = now
        state.recentGiftRequestIDs.append(requestID)
        interact(activity: "gift", now: now, state: &state)
        state.currentAnimation = animation
        if !state.unlockedAnimations.contains(animation) { state.unlockedAnimations.append(animation) }
        append(WattTransaction(id: requestID, timestamp: now, type: .gift, amount: -amount,
                               resultingBalance: state.wattsBalance, relatedActivity: "gift"), to: &state)
    }

    public static func giftAnimation(amount: Int64, mood: PetMood, roll: Int) -> String {
        let roll = min(10, max(1, roll))
        if amount == 0 { return "tongue" }
        if amount < 100 { return "yawn" }
        if amount < 300 { return "happy" }
        if amount < 400 { return roll >= 5 ? "hearts" : "flip" }
        if amount < 500 { return roll <= 4 || mood == .mad ? "hearts" : roll <= 8 ? "flip" : "letter" }
        if amount < 700 { return roll <= 3 ? "hearts" : roll <= 6 ? "flip" : "letter" }
        if amount < 800 { return roll <= 4 ? "ball" : roll <= 8 ? "diving" : "flying" }
        // Includes 899, closing the original browser's accidental gap.
        if amount < 900 { return roll <= 3 ? "piano" : roll <= 6 ? "flying" : roll <= 8 ? "diving" : "ball" }
        return roll <= 2 ? "piano" : roll <= 4 ? "flying" : roll <= 6 ? "diving" : roll <= 8 ? "ball" : "horn"
    }

    static func append(_ transaction: WattTransaction, to state: inout PetState) {
        state.transactions.append(transaction)
        state.transactions = Array(state.transactions.suffix(historyLimit))
    }
}
