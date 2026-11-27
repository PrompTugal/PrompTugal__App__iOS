import PTCore
import SwiftUI

/// Alerts: opt-in local notifications, one switch per topic. Permission is asked only when a switch is turned on.
/// Checks read public files (the same for every reader); which towns you follow never leaves the phone.
public struct AlertsSettingsView: View {
    @State private var center = AlertsCenter.shared
    @State private var busy: String?

    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(AlertTopics.all.indices, id: \.self) { index in
                    topicRow(AlertTopics.all[index])
                }
            } footer: {
                Text(LocalText.string("Local notifications only, at most one a day for each and none between 22:00 and 08:00. The app reads public files that are the same for everyone and picks what concerns your towns on this phone. Which towns you follow never leaves it."))
            }
            Section {
                followedLine
                if let message = center.message {
                    Text(message).font(.footnote).foregroundStyle(Palette.amber)
                }
                if let last = center.lastCheck {
                    Text(LocalText.string("Last checked \(Freshness.time(last, timeZone: .current))"))
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
            }
        }
        .navigationTitle(LocalText.string("Alerts"))
        .task { await center.check() }
    }

    private func topicRow(_ topic: any AlertTopic) -> some View {
        let binding = Binding<Bool>(
            get: { center.isOn(topic.id) },
            set: { on in
                busy = topic.id
                Task {
                    await center.set(topic.id, on: on)
                    busy = nil
                }
            }
        )
        return Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title).font(.body)
                Text(topic.summary).font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        .disabled(busy != nil)
    }

    @ViewBuilder private var followedLine: some View {
        let names = center.followed.map { PlaceDirectory.info($0)?.name ?? $0.capitalized }
        if names.isEmpty {
            Text(LocalText.string("You follow no towns yet. Follow one on its page and alerts will cover it."))
                .font(.footnote).foregroundStyle(Palette.muted)
        } else {
            Text(LocalText.string("Covering: \(names.joined(separator: ", "))"))
                .font(.footnote).foregroundStyle(Palette.ink)
        }
    }
}
