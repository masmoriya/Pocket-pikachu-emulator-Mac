import SwiftUI
import WidgetKit

struct PetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons
    let entry: PetWidgetEntry

    private var isPrivate: Bool { redactionReasons.contains(.privacy) }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, !isPrivate {
                switch family {
                case .accessoryInline:
                    Label("\(stepsLabel(snapshot)) · \(snapshot.watts.formatted()) W", systemImage: "bolt.fill")
                case .accessoryCircular:
                    circular(snapshot)
                default:
                    rectangular(snapshot)
                }
            } else {
                Label(isPrivate ? "Pocket Pikachu" : "Open app", systemImage: "bolt.heart")
                    .font(.caption)
                    .accessibilityLabel(isPrivate ? "Pocket Pikachu" : "Open Pocket Pikachu to save your pet")
            }
        }
        .privacySensitive()
    }

    private func sprite(_ snapshot: PetSnapshot) -> some View {
        WidgetPetSprite(frameID: snapshot.frameID, colored: snapshot.colored ?? true)
    }

    private func circular(_ snapshot: PetSnapshot) -> some View {
        ZStack {
            if let progress = snapshot.goalProgress(at: entry.date) {
                Gauge(value: progress) { Text("Daily steps") }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.green)
                    .accessibilityHidden(true)
            }
            sprite(snapshot).frame(width: 36, height: 30)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pikachu, \(snapshot.mood), \(stepsLabel(snapshot)), \(snapshot.watts) watts, last saved")
    }

    private func rectangular(_ snapshot: PetSnapshot) -> some View {
        HStack(spacing: 8) {
            sprite(snapshot).frame(width: 54, height: 45)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.mood).font(.headline).lineLimit(1)
                Text("\(stepsLabel(snapshot)) · \(snapshot.watts.formatted()) W")
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                if let progress = snapshot.goalProgress(at: entry.date) {
                    ProgressView(value: progress)
                        .tint(.green)
                        .accessibilityLabel("Daily step goal")
                        .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
                }
                Text(snapshot.date, style: .relative)
                    .font(.caption2).foregroundStyle(.secondary)
                    .accessibilityLabel("Last saved \(snapshot.date.formatted())")
            }
        }
    }

    private func stepsLabel(_ snapshot: PetSnapshot) -> String {
        guard let steps = snapshot.currentSteps(at: entry.date) else { return "— steps" }
        return "\(steps.formatted()) steps"
    }
}
