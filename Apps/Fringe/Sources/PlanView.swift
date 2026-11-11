import SwiftUI
import PTAgenda
import PTCore
import PTFringe

/// My plan: PTAgenda's My program (the picks in time order, clashes marked, free time, reminders, Add to Calendar).
struct PlanView: View {
    let chooseEvents: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            MyProgramView(chooseTalks: chooseEvents, open: { openURL($0) })
        }
    }
}
