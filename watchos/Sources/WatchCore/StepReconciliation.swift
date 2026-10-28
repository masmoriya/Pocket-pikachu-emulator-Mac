import Foundation

public struct StepSample: Codable, Equatable, Sendable {
    public var id: String
    public var sourceID: String
    public var sourcePriority: Int
    public var start: Date
    public var end: Date
    public var steps: Double
    public init(id: String, sourceID: String, sourcePriority: Int,
                start: Date, end: Date, steps: Double) {
        self.id = id; self.sourceID = sourceID; self.sourcePriority = sourcePriority
        self.start = start; self.end = end; self.steps = steps
    }
}

public struct StepLedger: Codable, Equatable, Sendable {
    public var windowStart: Date?
    public var through: Date?
    public var cursor: String?
    public var samples: [StepSample] = []
    public var finalizedEligibleSteps: Double = 0
    public var observedEligibleSteps: Int64 = 0
    public var creditedHighWater: Int64 = 0
    public var correctionDebt: Int64 { max(0, creditedHighWater - observedEligibleSteps) }
    public init() {}
}

public extension GameEngine {
    static func todaySteps(samples: [StepSample], on date: Date, calendar: Calendar = .current) -> Int64 {
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return 0 }
        return Int64(eligibleStepCount(samples: samples, start: interval.start,
                                      end: min(date, interval.end)).rounded(.down))
    }

    /// Authoritative complete snapshot of [windowStart, through], never an anchored delta.
    /// Keep a rolling seven-day UTC interval (not calendar days). On advancing its
    /// start, freeze the old snapshot's retired portion. Corrections outside this
    /// bounded window are deliberately ignored. Within it, all deletions and
    /// replacements recalculate the same canonical total. A monotonic high-water
    /// mark prevents replacement records from re-awarding already spent watts;
    /// corrections create step debt, recovered by future walking, never negative watts.
    static func reconcile(samples: [StepSample], windowStart: Date, through: Date,
                          cursor: String, state: inout PetState) throws {
        guard windowStart <= through, through.timeIntervalSince(windowStart) <= 8 * 86400,
              state.reconciliation.windowStart.map({ windowStart >= $0 }) ?? true,
              state.reconciliation.through.map({ through >= $0 }) ?? true else {
            throw GameError.invalidStepWindow
        }
        guard samples.allSatisfy({ !$0.id.isEmpty && !$0.sourceID.isEmpty &&
            $0.steps.isFinite && $0.steps >= 0 && $0.steps <= 10_000_000 && $0.end > $0.start }) else {
            throw GameError.invalidSample
        }
        var ledger = state.reconciliation
        if let oldStart = ledger.windowStart, let oldThrough = ledger.through, windowStart > oldStart {
            ledger.finalizedEligibleSteps += eligibleStepCount(
                samples: ledger.samples, start: oldStart, end: min(windowStart, oldThrough))
        }
        // Duplicate UUIDs choose a deterministic record, including on corrected input.
        let ordered = samples.sorted(by: samplePrecedes)
        var seen = Set<String>()
        ledger.samples = ordered.filter { seen.insert($0.id).inserted && $0.end > windowStart && $0.start < through }
        let observed = ledger.finalizedEligibleSteps + eligibleStepCount(
            samples: ledger.samples, start: windowStart, end: through)
        guard observed.isFinite, observed < Double(Int64.max / 2) else { throw GameError.invalidSample }
        ledger.observedEligibleSteps = Int64(observed.rounded(.down))
        let newlyEligible = max(0, ledger.observedEligibleSteps - ledger.creditedHighWater)
        ledger.creditedHighWater += newlyEligible
        ledger.windowStart = windowStart; ledger.through = through; ledger.cursor = cursor
        // Carry partial walking through a rate change. Only fresh eligible steps
        // trigger conversion: toggling rates or replaying a snapshot earns nothing.
        let rate = max(1, state.settings.stepsPerWatt)
        let steps = state.stepRemainder + newlyEligible
        let watts = newlyEligible > 0 ? steps / rate : 0
        if newlyEligible > 0 { state.stepRemainder = steps % rate }
        state.lifetimeStepsCredited += newlyEligible
        state.lifetimeWattsEarned += watts
        state.wattsBalance += watts
        state.reconciliation = ledger
        state.lastStepSyncDate = through
        state.lastStateUpdateDate = through
        if watts > 0 {
            append(WattTransaction(id: "steps-\(ledger.creditedHighWater)", timestamp: through,
                                   type: .walking, amount: watts, resultingBalance: state.wattsBalance,
                                   relatedActivity: "walking"), to: &state)
        }
    }

    /// Uniform contribution within each sample. Partition time at record edges;
    /// prefer watch (priority 0), then phone (1), then others (2). Ties use source
    /// identity then sample identity. Only one record contributes to each slice,
    /// even if two records share a source. No summing overlapping device totals.
    static func eligibleStepCount(samples: [StepSample], start: Date, end: Date) -> Double {
        guard start < end else { return 0 }
        let records = samples.filter {
            $0.end > start && $0.start < end && $0.end > $0.start && $0.steps.isFinite && $0.steps >= 0
        }.sorted { $0.start < $1.start }
        let edges = Set(records.flatMap { [max(start, $0.start), min(end, $0.end)] }).sorted()
        guard edges.count > 1 else { return 0 }
        var result: Double = 0
        var next = 0
        var heap: [StepSample] = []
        for index in 1..<edges.count {
            let left = edges[index - 1], right = edges[index]
            while next < records.count && records[next].start <= left {
                insert(records[next], into: &heap)
                next += 1
            }
            // Expired lower-ranked records remain lazy until they reach the root.
            while let first = heap.first, first.end <= left { removeFirst(from: &heap) }
            if let winner = heap.first {
                result += winner.steps * right.timeIntervalSince(left) / winner.end.timeIntervalSince(winner.start)
            }
        }
        return result
    }

    private static func insert(_ sample: StepSample, into heap: inout [StepSample]) {
        heap.append(sample)
        var child = heap.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard samplePrecedes(heap[child], heap[parent]) else { break }
            heap.swapAt(child, parent)
            child = parent
        }
    }

    private static func removeFirst(from heap: inout [StepSample]) {
        if heap.count == 1 { heap.removeLast(); return }
        heap[0] = heap.removeLast()
        var parent = 0
        while parent * 2 + 1 < heap.count {
            var child = parent * 2 + 1
            if child + 1 < heap.count && samplePrecedes(heap[child + 1], heap[child]) { child += 1 }
            guard samplePrecedes(heap[child], heap[parent]) else { return }
            heap.swapAt(child, parent)
            parent = child
        }
    }

    private static func samplePrecedes(_ lhs: StepSample, _ rhs: StepSample) -> Bool {
        if lhs.sourcePriority != rhs.sourcePriority { return lhs.sourcePriority < rhs.sourcePriority }
        if lhs.sourceID != rhs.sourceID { return lhs.sourceID < rhs.sourceID }
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.end != rhs.end { return lhs.end < rhs.end }
        return lhs.steps < rhs.steps
    }
}
