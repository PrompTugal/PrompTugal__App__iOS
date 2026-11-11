import SwiftUI
import PTAgenda
import PTCore
import PTFringe

/// The status as a small coloured label: on, moved, cancelled, online, or unknown.
struct StatusBadge: View {
    let status: FringeStatus

    var body: some View {
        Text(status.label)
            .font(Typo.kicker)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .on: Palette.green
        case .moved: Palette.amber
        case .cancelled: Palette.red
        case .online: Palette.blue
        case .unknown: Palette.muted
        }
    }
}

/// One line of the lists: time, name, organiser and place, the status.
struct EventRow: View {
    let event: FringeEvent
    var showDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(showDay ? "\(FringeFilter.dayLabel(event.date)) · \(event.timeLabel)" : event.timeLabel)
                    .font(Typo.data).foregroundStyle(Palette.muted)
                Spacer()
                StatusBadge(status: event.statusValue)
            }
            Text(event.name).font(Typo.headline).foregroundStyle(Palette.ink)
                .strikethrough(event.isCancelled)
            if !event.organiser.isEmpty { Text(event.organiser).font(Typo.meta).foregroundStyle(Palette.muted) }
            if !event.place.isEmpty { Text(event.place).font(Typo.meta).foregroundStyle(Palette.muted) }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// The full event: every fact with where it was read, how to join, the storm note, and the pick.
struct EventDetail: View {
    let event: FringeEvent
    @Environment(ScheduleStore.self) private var schedule
    @Environment(\.openURL) private var openURL

    var body: some View {
        Page(maxWidth: 700) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    Kicker(FringeFilter.kindLabel(event.kind))
                    StatusBadge(status: event.statusValue)
                }
                Text(event.name).font(Typo.title).strikethrough(event.isCancelled)
                if !event.organiser.isEmpty { Text(event.organiser).font(Typo.body).foregroundStyle(Palette.muted) }
            }
            Card {
                fact("When", "\(FringeFilter.dayLabel(event.date)), \(event.timeLabel) (Lisbon time)")
                if !event.place.isEmpty { fact("Where", event.place) }
                if !event.join.isEmpty { fact("How to join", event.join) }
                if !event.topics.isEmpty { fact("Topics", event.topics.joined(separator: ", ")) }
            }
            if !event.stormNote.isEmpty {
                Card {
                    Kicker(String(localized: "The storm"), color: Palette.amber)
                    Text(event.stormNote).font(Typo.body)
                }
            }
            if !event.note.isEmpty { Text(event.note).font(Typo.meta).foregroundStyle(Palette.muted) }
            if event.isPickable {
                Button { schedule.toggle(event.planEvent) } label: {
                    Label(schedule.isPicked(event.planEvent) ? "In my plan" : "Add to my plan",
                          systemImage: schedule.isPicked(event.planEvent) ? "star.fill" : "star")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text(event.isCancelled ? "Cancelled events cannot be added to a plan." : "This event has no published start time yet, so it cannot be added to a plan.")
                    .font(Typo.meta).foregroundStyle(Palette.muted)
            }
            if let url = event.url {
                Button { openURL(url) } label: { Label("Open the source page", systemImage: "safari").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
            }
            sourceLine
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fact(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Typo.kicker).foregroundStyle(Palette.muted)
            Text(value).font(Typo.body)
        }
    }

    /// Where the team read it and when, so nobody takes a guess for a fact.
    private var sourceLine: some View {
        let checked = event.verified ? "Checked." : "Not yet checked."
        var text = "When this was read is not published."
        if let date = event.readDate {
            text = "Read from the source at \(FringeFilter.dayLabel(Lisbon.day(date))), \(Lisbon.timeLabel(date)). \(checked)"
        }
        return Text(text).font(Typo.meta).foregroundStyle(Palette.muted)
    }
}
