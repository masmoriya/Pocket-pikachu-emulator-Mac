import SwiftUI
import WatchCore

struct MenuView: View {
    @ObservedObject var model: CompanionModel
    var returnToClock: () -> Void
    @Environment(\.dismiss) private var dismiss
    private let activities: [(String, String)] = [
        ("Feed", "toast"), ("Play", "rc"), ("Read", "reading"), ("Study", "history"),
        ("Bathe", "bath"), ("Brush teeth", "brush"), ("Blocks", "blocks"),
        ("Fly kite", "kite"), ("Yo-yo", "yoyo"), ("Walk", "walk"), ("Rest", "sleep-front")
    ]
    var body: some View {
        List {
            Text(model.state.mood.label).foregroundStyle(.secondary)
            NavigationLink("Give gift") { GiftView(model: model, returnToClock: returnToClock) }
            ForEach(activities, id: \.1) { title, animation in
                Button(title) { model.interact(animation); dismiss() }
            }
            Button("Idle") { model.interact("idle"); dismiss() }
            NavigationLink("Watts") { WattsView(model: model) }
            NavigationLink("Settings") { SettingsView(model: model) }
        }.navigationTitle("Pikachu")
    }
}

struct GiftView: View {
    @ObservedObject var model: CompanionModel
    var returnToClock: () -> Void
    @State private var amount = 10
    @State private var requestID = UUID().uuidString
    @State private var sent = false

    var body: some View {
        VStack {
            Text("\(model.state.wattsBalance.formatted()) watts").foregroundStyle(.secondary)
            Picker("Gift watts", selection: $amount) {
                ForEach([1, 10, 50, 100, 300, 500, 999], id: \.self) { value in
                    Text(value.formatted()).tag(value)
                }
            }.pickerStyle(.wheel)
            Button("Give \(amount)") {
                guard !sent else { return }
                if model.gift(Int64(amount), requestID: requestID) {
                    sent = true
                    returnToClock()
                }
            }
            .disabled(sent || Int64(amount) > model.state.wattsBalance)
        }.navigationTitle("Gift")
    }
}

struct WattsView: View {
    @ObservedObject var model: CompanionModel
    var body: some View {
        List {
            Text("\(model.state.wattsBalance.formatted()) watts").font(.title3)
            Text("\(model.state.stepRemainder)/20 steps toward next watt").font(.footnote)
            ForEach(model.state.transactions.reversed()) { transaction in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(transaction.type == .walking ? "Walking" : "Gift")
                        Spacer()
                        Text(transaction.amount.formatted(.number.sign(strategy: .always())))
                    }
                    Text(transaction.timestamp, style: .date).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("Watts")
    }
}
