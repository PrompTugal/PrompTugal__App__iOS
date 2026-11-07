import SwiftUI

/// "My next 3 hours": a compact card for the Today screen, sized for iPhone. My picks and stand-ups starting (or
/// running) in the next three hours, with a countdown in Lisbon time; when there are none, three sessions starting
/// soon, each one tap from my day. Design embeds it: `NextHoursCard()` (needs `.teamFeatures()` above it).
struct NextHoursCard: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(PlannerStore.self) private var planner
    @Environment(\.openURL) private var openURL

    var hours: Double = 3

    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
        let start: Date
        let end: Date
        let url: URL?
        let mine: Bool
        let event: Event?
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let mine = upcomingMine(now: now)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(mine.isEmpty ? "Starting soon" : "My next \(Int(hours)) hours")
                        .font(.headline)
                    Spacer()
                    Text("\(Lisbon.timeLabel(now)) Lisbon")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                let items = mine.isEmpty ? soon(now: now) : mine
                if items.isEmpty {
                    Text("Nothing in the next \(Int(hours)) hours.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(items) { item in row(item, now: now) }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        }
    }

    private func row(_ item: Item, now: Date) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(Lisbon.timeLabel(item.start)).font(.subheadline.monospacedDigit().bold())
                Text(countdown(item, now: now)).font(.caption2.monospacedDigit())
                    .foregroundStyle(item.start <= now ? Color.green : Color.secondary)
            }
            .frame(width: 64, alignment: .trailing)
            Button {
                if let url = item.url { openURL(url) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                    if !item.detail.isEmpty {
                        Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if let event = item.event, !item.mine {
                Button {
                    schedule.toggle(event)
                } label: {
                    Image(systemName: schedule.isPicked(event) ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(schedule.isPicked(event) ? "Remove from my day" : "Add to my day")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func countdown(_ item: Item, now: Date) -> String {
        if item.start <= now { return "now" }
        let minutes = Int(item.start.timeIntervalSince(now) / 60)
        return minutes < 60 ? "in \(max(1, minutes)) min" : "in \(minutes / 60) h \(minutes % 60)"
    }

    func upcomingMine(now: Date) -> [Item] {
        let horizon = now.addingTimeInterval(hours * 3600)
        var items: [Item] = schedule.picks.compactMap { pick in
            guard let start = pick.start else { return nil }
            let end = pick.end ?? start.addingTimeInterval(30 * 60)
            guard end > now, start < horizon else { return nil }
            let going = planner.teammates(for: pick.id)
            let detail = [pick.event?.place ?? "", going.isEmpty ? "" : "with \(going.joined(separator: ", "))"]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            return Item(id: "pick.\(pick.id)", title: pick.title, detail: detail, start: start, end: end,
                        url: pick.url, mine: true, event: pick.event)
        }
        if let me = identity.current?.id {
            items += team.standups.filter { $0.end > now && $0.at < horizon }.map {
                Item(id: "standup.\($0.slot)", title: "Team stand-up", detail: "Open my briefing", start: $0.at,
                     end: $0.end, url: $0.briefingURL(for: me), mine: true, event: nil)
            }
        }
        return items.sorted { $0.start < $1.start }
    }

    func soon(now: Date) -> [Item] {
        let horizon = now.addingTimeInterval(hours * 3600)
        return planner.agenda.lazy.compactMap { event -> Item? in
            guard let start = event.start, start > now, start < horizon else { return nil }
            return Item(id: event.page, title: event.title, detail: event.place, start: start,
                        end: event.end ?? start.addingTimeInterval(30 * 60), url: event.url, mine: false, event: event)
        }
        .sorted { $0.start < $1.start }
        .prefix(3).map { $0 }
    }
}
