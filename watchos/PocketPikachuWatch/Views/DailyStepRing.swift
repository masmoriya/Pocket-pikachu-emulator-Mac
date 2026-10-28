import SwiftUI

struct DailyStepRing: View {
    let steps: Int?
    let goal: Int

    private var progress: Double {
        guard let steps else { return 0 }
        return min(1, max(0, Double(steps) / Double(max(1, goal))))
    }

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 3)
            if steps != nil {
                Circle().trim(from: 0, to: progress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Image(systemName: "figure.walk").font(.system(size: 10))
                Text(steps.map { $0.formatted(.number.notation(.compactName)) } ?? "—")
                    .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .frame(width: 38, height: 38)
        .padding(3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(steps.map { "\($0) of \(goal) daily steps" } ?? "Daily steps unavailable")
        .accessibilityValue(steps.map { _ in "\(Int(progress * 100)) percent of goal" } ?? "No accessible step data")
    }
}
