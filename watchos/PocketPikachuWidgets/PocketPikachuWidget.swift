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
        let snapshot = SharedSnapshotStore.read()
        var entries = [PetWidgetEntry(date: now, snapshot: snapshot)]
        // Preload rollover so yesterday's steps disappear even if a refresh is delayed.
        if let midnight = Calendar.current.date(byAdding: .day, value: 1,
                                                to: Calendar.current.startOfDay(for: now)) {
            entries.append(PetWidgetEntry(date: midnight, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
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
        .description("Pikachu, your daily step goal and saved watts.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
