import SwiftUI
import WatchCore

struct RoutineSettingsView: View {
    @ObservedObject var model: CompanionModel
    var body: some View {
        List {
            Picker("Routine", selection: Binding(get: { model.state.settings.routineMode }, set: { value in
                var settings = model.state.settings
                settings.routineMode = value
                model.updateSettings(settings)
            })) {
                ForEach(RoutineMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            if model.state.settings.selectedActivity != nil {
                Button("Live freely") { model.selectActivity(nil) }
                Text("Manual activity is selected.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(model.state.settings.dailySchedule.sorted { $0.minute < $1.minute }) { entry in
                NavigationLink {
                    ScheduleEntryView(model: model, entry: entry)
                } label: {
                    VStack(alignment: .leading) {
                        Text(time(for: entry.minute))
                        Text(model.activityChoices.first { $0.id == entry.activity }?.label ?? entry.activity)
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if model.state.settings.dailySchedule.count < 48 {
                NavigationLink("Add time") { ScheduleEntryView(model: model) }
            }
        }.navigationTitle("Routine")
    }
    private func time(for minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
        return ClockFormatting.string(date: date, format: model.state.settings.clockFormat, locale: .current, timeZone: .current)
    }
}

private struct ScheduleEntryView: View {
    @ObservedObject var model: CompanionModel
    @Environment(\.dismiss) private var dismiss
    private let existingID: UUID?
    @State private var hour: Int
    @State private var minute: Int
    @State private var activity: String

    init(model: CompanionModel, entry: DailyActivity? = nil) {
        self.model = model
        existingID = entry?.id
        _hour = State(initialValue: (entry?.minute ?? 720) / 60)
        _minute = State(initialValue: (entry?.minute ?? 720) % 60)
        _activity = State(initialValue: entry?.activity ?? "reading")
    }
    var body: some View {
        List {
            Picker("Hour", selection: $hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            Picker("Minute", selection: $minute) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            Picker("Activity", selection: $activity) {
                ForEach(model.activityChoices) { Text($0.label).tag($0.id) }
            }
            Button("Save") { save(remove: false) }
            if existingID != nil { Button("Remove", role: .destructive) { save(remove: true) } }
        }.navigationTitle("Schedule time")
    }
    private func save(remove: Bool) {
        var settings = model.state.settings
        settings.dailySchedule.removeAll { $0.id == existingID }
        if !remove {
            settings.dailySchedule.append(DailyActivity(id: existingID ?? UUID(), minute: hour * 60 + minute, activity: activity))
        }
        model.updateSettings(settings)
        dismiss()
    }
}
