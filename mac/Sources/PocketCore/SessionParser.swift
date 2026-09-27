import Foundation

public enum SessionParser {
    public struct Result: Sendable {
        public var session: SessionUsage?
        public var malformed = 0
    }
    public static func parse(_ data: Data, fallbackID: String, metadata: SessionUsage? = nil) -> Result {
        var result = Result()
        var id = metadata?.id ?? fallbackID
        var parent = metadata?.parent, fork = metadata?.forkTime
        var sawIdentity = metadata != nil
        var isSubagent = metadata?.isSubagent
        var samples: [TokenSample] = []
        // Partial final records remain unread until the next append.
        let lines = data.split(separator: 10, omittingEmptySubsequences: false).dropLast()
        for line in lines where !line.isEmpty {
            // Skip content records without decoding or retaining their payloads.
            guard contains(line, "token_count") || contains(line, "session_meta") else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let type = object["type"] as? String,
                  let payload = object["payload"] as? [String: Any] else { result.malformed += 1; continue }
            if type == "session_meta" {
                if sawIdentity {
                    if let ancestor = payload["id"] as? String, ancestor != id, parent == nil { parent = ancestor }
                    continue
                }
                sawIdentity = true
                isSubagent = (payload["source"] as? [String: Any])?["subagent"] != nil
                id = payload["id"] as? String ?? id
                parent = payload["forked_from_id"] as? String ?? payload["parent_session_id"] as? String
                fork = date(payload["forked_at"] as? String ?? payload["timestamp"] as? String ?? object["timestamp"] as? String)
                continue
            }
            guard type == "event_msg", payload["type"] as? String == "token_count" else { continue }
            // A nil info record is emitted by Codex before any usage is available.
            if payload["info"] == nil || payload["info"] is NSNull { continue }
            guard let info = payload["info"] as? [String: Any],
                  let total = info["total_token_usage"] as? [String: Any],
                  let input = count(total["input_tokens"]), let output = count(total["output_tokens"]),
                  input <= Int64.max - output,
                  let timestamp = date(object["timestamp"] as? String) else { result.malformed += 1; continue }
            let last = info["last_token_usage"] as? [String: Any]
            let lastInput = count(last?["input_tokens"]), lastOutput = count(last?["output_tokens"])
            let lastTotal: Int64? = if let lastInput, let lastOutput, lastInput <= Int64.max - lastOutput { lastInput + lastOutput } else { nil }
            samples.append(TokenSample(timestamp: timestamp, total: input + output, last: lastTotal))
        }
        result.session = SessionUsage(id: id, parent: parent, forkTime: fork, samples: samples)
        result.session?.isSubagent = isSubagent
        return result
    }
    private static func contains(_ data: Data.SubSequence, _ value: String) -> Bool {
        data.range(of: Data(value.utf8)) != nil
    }
    private static func count(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue >= 0,
              number.doubleValue < Double(Int64.max), number.doubleValue.rounded() == number.doubleValue else { return nil }
        return number.int64Value
    }
    private static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
import CoreFoundation
