import Foundation

public struct TokenSample: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var total: Int64
    public var last: Int64?
    public init(timestamp: Date, total: Int64, last: Int64? = nil) { self.timestamp = timestamp; self.total = total; self.last = last }
}
public struct SessionUsage: Codable, Sendable {
    public var id: String
    public var parent: String?
    public var forkTime: Date?
    public var samples: [TokenSample]
    public var isSubagent: Bool?
    public init(id: String, parent: String? = nil, forkTime: Date? = nil, samples: [TokenSample]) {
        self.id = id; self.parent = parent; self.forkTime = forkTime; self.samples = samples
    }
}
public struct UsageLedger: Codable, Sendable {
    public var startedAt: Date?
    public var sessions: [String: SessionUsage] = [:]
    public var credited: [String: Int64] = [:]
    public init() {}

    public mutating func reconcile(_ updates: [SessionUsage], now: Date) -> Int64 {
        let first = startedAt == nil
        if first { startedAt = now }
        for update in updates {
            if var existing = sessions[update.id] {
                existing.parent = update.parent ?? existing.parent
                existing.forkTime = update.forkTime ?? existing.forkTime
                existing.isSubagent = update.isSubagent ?? existing.isSubagent
                let merged = existing.samples + update.samples
                existing.samples = Array(Set(merged.map(SampleKey.init)))
                    .map { TokenSample(timestamp: $0.timestamp, total: $0.total, last: $0.last) }
                    .sorted { $0.timestamp < $1.timestamp }
                sessions[update.id] = existing
            } else { sessions[update.id] = update }
        }
        var awarded: Int64 = 0
        for id in sessions.keys.sorted() {
            let available = contribution(id, after: startedAt!, before: .distantFuture, visiting: [])
            let previous = credited[id, default: 0]
            if !first { awarded += max(0, available - previous) }
            credited[id] = max(previous, available)
        }
        return awarded
    }
    // Fork logs contain inherited events. Only post-fork increases belong to a child.
    private func contribution(_ id: String, after start: Date, before end: Date, visiting: Set<String>) -> Int64 {
        guard let session = sessions[id], !visiting.contains(id) else { return 0 }
        // Defer direct forks until ancestry is available; never charge an inherited prefix.
        if !lineageAvailable(id, visiting: []) { return 0 }
        let cutoff = max(start, session.forkTime ?? .distantPast)
        var high: Int64 = 0
        if let parent = session.parent, let fork = session.forkTime {
            high = snapshot(parent, at: fork, visiting: visiting.union([id]))
        }
        var result: Int64 = 0
        for sample in session.samples.sorted(by: { $0.timestamp < $1.timestamp }) where sample.timestamp <= end {
            if sample.timestamp > cutoff {
                if (sample.total < high || (high == 0 && session.isSubagent == true)), let last = sample.last { result += min(sample.total, last) }
                else { result += max(0, sample.total - high) }
            }
            if sample.total >= high || sample.last != nil { high = sample.total }
        }
        return result
    }
    private func lineageAvailable(_ id: String, visiting: Set<String>) -> Bool {
        guard let session = sessions[id], !visiting.contains(id) else { return false }
        guard let parent = session.parent else { return true }
        return lineageAvailable(parent, visiting: visiting.union([id]))
    }
    private func snapshot(_ id: String, at date: Date, visiting: Set<String>) -> Int64 {
        guard let session = sessions[id], !visiting.contains(id) else { return 0 }
        let inherited = session.parent.map {
            snapshot($0, at: min(date, session.forkTime ?? date), visiting: visiting.union([id]))
        } ?? 0
        return max(inherited, session.samples.filter { $0.timestamp <= date }.map(\.total).max() ?? 0)
    }
    private struct SampleKey: Hashable {
        var timestamp: Date
        var total: Int64
        var last: Int64?
        init(_ sample: TokenSample) { timestamp = sample.timestamp; total = sample.total; last = sample.last }
    }
}
