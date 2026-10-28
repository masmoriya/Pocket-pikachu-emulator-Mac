import SwiftUI

struct ActivityGalleryView: View {
    @ObservedObject var model: CompanionModel
    var returnToClock: () -> Void
    var body: some View {
        List {
            Button("Live freely") { model.selectActivity(nil); returnToClock() }
            ForEach(model.activityChoices) { activity in
                NavigationLink(activity.label) {
                    VStack {
                        PikachuSpriteView(animationID: activity.id, colored: model.state.settings.colored,
                                          reducedMotion: model.state.settings.reducedAnimation, repeatFinite: true)
                            .frame(maxHeight: 130)
                        Button("Choose") { model.selectActivity(activity.id); returnToClock() }
                    }.navigationTitle(activity.label)
                }
            }
        }.navigationTitle("Activities")
    }
}
