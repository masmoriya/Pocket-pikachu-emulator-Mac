import Combine
import Foundation
import HealthKit
import WatchCore

struct StepSnapshot: Sendable {
    let samples: [StepSample]
    let windowStart: Date
    let through: Date
    let cursor: String
}

protocol StepDataProvider: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    func snapshot() async throws -> StepSnapshot
}

enum StepAccessError: Error, LocalizedError, Equatable {
    case unavailable, authorizationFailed, queryFailed, sampleLimitExceeded

    var errorDescription: String? {
        switch self {
        case .unavailable: "Health data is unavailable."
        case .authorizationFailed: "Health connection could not complete. Try again."
        case .queryFailed: "Steps could not sync. Try again."
        case .sampleLimitExceeded: "Too many step records to sync safely."
        }
    }
}

/// HealthKit owns all mutable state internally; this wrapper only holds immutable dependencies.
final class HealthKitStepProvider: StepDataProvider, @unchecked Sendable {
    private let store: HKHealthStore
    private let now: @Sendable () -> Date
    private let sampleLimit = 50_000

    init(store: HKHealthStore = HKHealthStore(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Request completion does not reveal read permission: HealthKit deliberately hides that state.
    func requestAuthorization() async throws {
        guard isAvailable else { throw StepAccessError.unavailable }
        let steps = HKQuantityType(.stepCount)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: [steps]) { success, _ in
                if success { continuation.resume() }
                else { continuation.resume(throwing: StepAccessError.authorizationFailed) }
            }
        }
    }

    func snapshot() async throws -> StepSnapshot {
        guard isAvailable else { throw StepAccessError.unavailable }
        let through = now()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = calendar.startOfDay(for: through)
        let start = calendar.date(byAdding: .day, value: -6, to: midnight)!
        // Default overlap semantics include records crossing the left boundary. Core clips them.
        let predicate = HKQuery.predicateForSamples(withStart: start, end: through, options: [])
        let limit = sampleLimit
        let samples: [StepSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKQuantityType(.stepCount), predicate: predicate,
                                      limit: limit + 1, sortDescriptors: nil) { _, records, error in
                guard error == nil, let records else {
                    continuation.resume(throwing: StepAccessError.queryFailed)
                    return
                }
                // An incomplete authoritative snapshot would misclassify existing records as deleted.
                guard records.count <= limit else {
                    continuation.resume(throwing: StepAccessError.sampleLimitExceeded)
                    return
                }
                let samples = records.compactMap { record -> StepSample? in
                    guard let sample = record as? HKQuantitySample else { return nil }
                    // Rewards represent recorded walking; user-entered totals are excluded consistently.
                    guard (sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber)?.boolValue != true else {
                        return nil
                    }
                    let revision = sample.sourceRevision
                    let product = revision.productType ?? sample.device?.model ?? "unknown"
                    let model = product.lowercased()
                    let priority = model.hasPrefix("watch") || model.contains("apple watch") ? 0
                        : model.hasPrefix("iphone") ? 1 : 2
                    // No app version in identity: updates must not create a new contributing source.
                    let sourceID = [revision.source.bundleIdentifier, product,
                                    sample.device?.localIdentifier ?? ""].joined(separator: "|")
                    return StepSample(id: sample.uuid.uuidString, sourceID: sourceID,
                                      sourcePriority: priority, start: sample.startDate,
                                      end: sample.endDate, steps: sample.quantity.doubleValue(for: .count()))
                }
                continuation.resume(returning: samples)
            }
            store.execute(query)
        }
        return StepSnapshot(samples: samples, windowStart: start, through: through,
                            cursor: String(through.timeIntervalSince1970))
    }
}

@MainActor
final class StepManager: ObservableObject {
    enum Status: Equatable {
        case unavailable, idle, loading, noData, ready, failed(String)
    }

    @Published private(set) var status: Status
    @Published private(set) var latestSnapshot: StepSnapshot?
    private let provider: any StepDataProvider

    init(provider: any StepDataProvider = HealthKitStepProvider()) {
        self.provider = provider
        status = provider.isAvailable ? .idle : .unavailable
    }

    /// Called only from an explicit Connect Health action, never during automatic resume refresh.
    func requestAuthorization() async {
        guard status != .loading else { return }
        latestSnapshot = nil
        status = .loading
        do {
            try await provider.requestAuthorization()
            status = .idle
            await refresh()
        } catch {
            setFailure(error)
        }
    }

    /// A complete rolling snapshot is fetched on resume or manual sync; there is no polling timer.
    func refresh() async {
        guard status != .loading else { return }
        guard provider.isAvailable else { status = .unavailable; return }
        latestSnapshot = nil
        status = .loading
        do {
            let snapshot = try await provider.snapshot()
            latestSnapshot = snapshot
            // Empty results can mean no records or no readable data; never infer denial.
            status = snapshot.samples.isEmpty ? .noData : .ready
        } catch {
            setFailure(error)
        }
    }

    private func setFailure(_ error: Error) {
        if let error = error as? StepAccessError {
            status = error == .unavailable ? .unavailable : .failed(error.localizedDescription)
        } else {
            // Avoid presenting or logging HealthKit payloads from arbitrary provider errors.
            status = .failed("Steps could not sync. Try again.")
        }
    }
}
