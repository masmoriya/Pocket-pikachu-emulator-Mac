import SwiftUI
import WidgetKit

struct PetWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PetSnapshot?
}

struct PetWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetWidgetEntry {
        PetWidgetEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetWidgetEntry) -> Void) {
        completion(PetWidgetEntry(date: .now, snapshot: SharedSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetWidgetEntry>) -> Void) {
        let now = Date.now
        let entry = PetWidgetEntry(date: now, snapshot: SharedSnapshotStore.read())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

@main
struct PocketPikachuWidget: Widget {
    let kind = "PocketPikachuPet"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetWidgetProvider()) { entry in
            PetWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "pocketpikachu://clock"))
        }
        .configurationDisplayName("Pocket Pikachu")
        .description("Your pet’s last saved mood, steps and watts.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct PetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons
    let entry: PetWidgetEntry

    private var isPrivate: Bool { redactionReasons.contains(.privacy) }

    private func stepsLabel(for snapshot: PetSnapshot) -> String {
        guard Calendar.current.isDate(snapshot.date, inSameDayAs: entry.date),
              let steps = snapshot.steps else { return "— steps" }
        return "\(steps) steps"
    }

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline:
                Text(isPrivate ? "Pocket Pikachu" : "\(snapshot.mood) · \(snapshot.watts) W")
                    .privacySensitive()
            case .accessoryCircular:
                VStack(spacing: 0) {
                    WidgetPetSprite(frameID: snapshot.frameID)
                        .frame(width: 36, height: 30)
                    if !isPrivate {
                        Text("\(snapshot.watts) W")
                            .font(.caption2)
                            .minimumScaleFactor(0.7)
                            .privacySensitive()
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isPrivate ? "Pocket Pikachu" : "\(snapshot.mood), \(snapshot.watts) watts, last saved")
            default:
                HStack(spacing: 6) {
                    WidgetPetSprite(frameID: snapshot.frameID)
                        .frame(width: 54, height: 45)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(snapshot.mood).font(.headline).lineLimit(1)
                        if !isPrivate {
                            Text("\(stepsLabel(for: snapshot)) · \(snapshot.watts) W")
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .privacySensitive()
                            Text(snapshot.date, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Last saved \(snapshot.date.formatted())")
                        }
                    }
                }
            }
        } else {
            Text("Open app")
                .font(.caption)
                .accessibilityLabel("Open Pocket Pikachu to save your pet")
        }
    }
}
