import XCTest
@testable import WatchCore

final class GameEngineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testOriginalFriendshipThresholds() {
        let cases: [(Int64, PetMood)] = [(-1500, .away), (-1499, .mad), (-500, .mad),
            (-499, .neutral), (1500, .neutral), (1501, .like), (3000, .like), (3001, .love)]
        for (points, mood) in cases { XCTAssertEqual(PetMood(points: points), mood) }
    }

    func testGiftSpendingAndRapidTapIdempotency() throws {
        var state = PetState(now: now)
        try GameEngine.giveGift(amount: 20, requestID: "purchase", roll: 1, now: now, state: &state)
        let saved = state
        XCTAssertThrowsError(try GameEngine.giveGift(amount: 20, requestID: "purchase", roll: 1,
                                                    now: now.addingTimeInterval(10), state: &state))
        XCTAssertThrowsError(try GameEngine.giveGift(amount: 20, requestID: "rapid", roll: 1,
                                                    now: now.addingTimeInterval(0.1), state: &state))
        XCTAssertEqual(state, saved)
        XCTAssertEqual(state.wattsBalance, 30)
        XCTAssertEqual(state.friendshipPoints, 20)
        XCTAssertEqual(state.lifetimeWattsSpent, 20)
        XCTAssertEqual(state.transactions.first?.amount, -20)
    }

    func testInsufficientAndInvalidPurchaseLeaveStateUnchanged() {
        var state = PetState(now: now)
        let original = state
        for amount: Int64 in [-1, 51, 1000] {
            XCTAssertThrowsError(try GameEngine.giveGift(amount: amount, requestID: "bad", roll: 1,
                                                        now: now, state: &state))
            XCTAssertEqual(state, original)
        }
    }

    func testZeroGiftOriginalPenaltyAndNoSuspensionPenalty() throws {
        var state = PetState(now: now)
        try GameEngine.giveGift(amount: 0, requestID: "zero", roll: 1, now: now, state: &state)
        XCTAssertEqual(state.friendshipPoints, -100)
        XCTAssertEqual(state.currentAnimation, "tongue")
        GameEngine.interact(activity: "reading", now: now.addingTimeInterval(86400 * 100), state: &state)
        XCTAssertEqual(state.friendshipPoints, -100)
    }

    func testHistoryBoundedWithoutForgettingPurchaseIdentity() throws {
        var state = PetState(now: now)
        for index in 0..<205 {
            try GameEngine.giveGift(amount: 0, requestID: "gift-\(index)", roll: 1,
                                   now: now.addingTimeInterval(Double(index * 2)), state: &state)
        }
        XCTAssertEqual(state.transactions.count, 200)
        XCTAssertThrowsError(try GameEngine.giveGift(amount: 0, requestID: "gift-0", roll: 1,
                                                    now: now.addingTimeInterval(1000), state: &state))
    }
}
