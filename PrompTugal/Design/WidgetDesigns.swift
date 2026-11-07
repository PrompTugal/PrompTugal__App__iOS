import SwiftUI

// Designs for the widgets and the Live Activity. They are plain SwiftUI views over plain
// values, so the platform session's widget target can use them as they are (WidgetKit and
// ActivityKit add only the timeline and the activity attributes around them).

/// What a widget needs, read from the App Group store. No vault data, no keys.
struct NextUpEntry: Sendable {
    struct Item: Identifiable, Sendable {
        let id: String
        let title: String
        let place: String
        let start: Date
        let end: Date?
        let kind: Kind
        enum Kind: Sendable { case session, standup, meeting }
    }

    let now: Date
    let items: [Item]
    let attention: Int       // only you + decide + overdue, from me.json
}

/// Small widget: the very next thing, how long until it starts, and my attention count.
struct NextUpSmallWidget: View {
    let entry: NextUpEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Kicker("Next")
                Spacer()
                if entry.attention > 0 {
                    Text("\(entry.attention)").font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Palette.red, in: Capsule()).foregroundStyle(.white)
                        .accessibilityLabel("\(entry.attention) things wait on you")
                }
            }
            if let item = entry.items.first {
                Text(item.title).font(.system(.subheadline, design: .serif, weight: .bold)).lineLimit(3)
                Spacer(minLength: 0)
                Text(item.start, style: .relative).font(.caption.monospacedDigit()).foregroundStyle(Palette.red)
                Text(item.place).font(.caption2).foregroundStyle(Palette.muted).lineLimit(1)
            } else {
                Spacer()
                Text("Nothing planned").font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
        .padding(14)
        .frame(width: 158, height: 158, alignment: .topLeading)
        .background(Palette.card)
    }
}

/// Medium widget: now and next, two items with a time rail.
struct NextUpMediumWidget: View {
    let entry: NextUpEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Kicker("PrompTugal")
                Text(entry.now, format: .dateTime.weekday(.abbreviated).day())
                    .font(.system(.title2, design: .serif, weight: .bold))
                Spacer()
                if entry.attention > 0 {
                    CountPill(count: entry.attention, label: "for you")
                }
            }
            .frame(width: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entry.items.prefix(2)) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Capsule().fill(color(item.kind)).frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.start, format: .dateTime.hour().minute()).font(.caption.monospacedDigit())
                                .foregroundStyle(color(item.kind))
                            Text(item.title).font(.footnote.weight(.semibold)).lineLimit(2)
                            Text(item.place).font(.caption2).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                    }
                }
                if entry.items.isEmpty {
                    Text("Nothing planned. Add sessions from the agenda.").font(.footnote).foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(14)
        .frame(width: 338, height: 158, alignment: .topLeading)
        .background(Palette.card)
    }

    private func color(_ kind: NextUpEntry.Item.Kind) -> Color {
        switch kind {
        case .session: Palette.red
        case .standup: Palette.green
        case .meeting: Palette.blue
        }
    }
}

/// Lock Screen Live Activity: from ten minutes before an item until it ends.
struct SessionLiveActivityView: View {
    let item: NextUpEntry.Item
    let now: Date

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Kicker(item.kind == .standup ? "Stand-up" : (now < item.start ? "Starting soon" : "Now"),
                       color: item.kind == .standup ? Palette.green : Palette.red)
                Text(item.title).font(.system(.headline, design: .serif)).lineLimit(2)
                Label(item.place, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if now < item.start {
                    Text(timerInterval: now...item.start, countsDown: true).font(.title2.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing).frame(width: 80)
                } else if let end = item.end {
                    ProgressView(timerInterval: item.start...end, countsDown: false)
                        .tint(Palette.red).frame(width: 80)
                    Text("ends \(end.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(16)
        .background(Palette.card)
    }
}

enum WidgetSamples {
    static var entry: NextUpEntry {
        let now = Date.now
        return NextUpEntry(now: now, items: [
            .init(id: "1", title: "AI: your new news editor?", place: "Centre Stage", start: now.addingTimeInterval(1_500),
                  end: now.addingTimeInterval(3_000), kind: .session),
            .init(id: "2", title: "Team stand-up", place: "Online", start: now.addingTimeInterval(5_400), end: nil, kind: .standup),
        ], attention: 7)
    }
}

#Preview("Widgets") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            NextUpSmallWidget(entry: WidgetSamples.entry).clipShape(RoundedRectangle(cornerRadius: 22))
            NextUpSmallWidget(entry: NextUpEntry(now: .now, items: [], attention: 0)).clipShape(RoundedRectangle(cornerRadius: 22))
        }
        NextUpMediumWidget(entry: WidgetSamples.entry).clipShape(RoundedRectangle(cornerRadius: 22))
        SessionLiveActivityView(item: WidgetSamples.entry.items[0], now: .now).clipShape(RoundedRectangle(cornerRadius: 22))
    }
    .padding()
    .background(Palette.paper2)
}
