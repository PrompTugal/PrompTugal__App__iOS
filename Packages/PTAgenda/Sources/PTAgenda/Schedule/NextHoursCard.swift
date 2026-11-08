import SwiftUI
import PTCore
import PTWeb

/// "My next 3 hours": a compact card for the Today screen, sized for iPhone. My picks and stand-ups starting (or
/// running) in the next three hours, with a countdown in Lisbon time; when there are none, three sessions starting
/// soon, each one tap from my day. Design embeds it: `NextHoursCard()` (needs `.teamFeatures()` above it).
public struct NextHoursCard: View {
    public init(hours: Double = 3) {
        self.hours = hours
    }

    @Environment(ScheduleStore.self) private var schedule
    @Environment(\.agendaTeam) private var team
    @Environment(\.agendaIdentity) private var identity
    @Environment(PlannerStore.self) private var planner
    @Environment(\.openURL) private var openURL

    public var hours: Double = 3

    public struct Item: Identifiable, Hashable {
        public init(id: String, title: String, detail: String, start: Date, end: Date, url: URL?, mine: Bool, event: Event?) {
            self.id = id
            self.title = title
            self.detail = detail
            self.start = start
            self.end = end
            self.url = url
            self.mine = mine
            self.event = event
        }

        public let id: String
        public let title: String
        public let detail: String
        public let start: Date
        public let end: Date
        public let url: URL?
        public let mine: Bool
        public let event: Event?
    }

    public var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let mine = upcomingMine(now: now)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(mine.isEmpty ? String(localized: "Starting soon", bundle: .module) : String(localized: "My next \(Int(hours)) hours", bundle: .module))
                        .font(.headline)
                    Spacer()
                    Text(String(localized: "\(Lisbon.timeLabel(now)) Lisbon", bundle: .module))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                let items = mine.isEmpty ? soon(now: now) : mine
                if items.isEmpty {
                    Text(String(localized: "Nothing in the next \(Int(hours)) hours.", bundle: .module)).font(.subheadline).foregroundStyle(.secondary)
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
                .accessibilityLabel(schedule.isPicked(event) ? String(localized: "Remove from my day", bundle: .module) : String(localized: "Add to my day", bundle: .module))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func countdown(_ item: Item, now: Date) -> String {
        if item.start <= now { return String(localized: "now", bundle: .module) }
        let minutes = Int(item.start.timeIntervalSince(now) / 60)
        return minutes < 60 ? String(localized: "in \(max(1, minutes)) min", bundle: .module) : String(localized: "in \(minutes / 60) h \(minutes % 60)", bundle: .module)
    }

    public func upcomingMine(now: Date) -> [Item] {
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
        if let me = identity?.currentID {
            items += (team?.standups ?? []).filter { $0.end > now && $0.at < horizon }.map {
                Item(id: "standup.\($0.slot)", title: String(localized: "Team stand-up", bundle: .module), detail: String(localized: "Open my briefing", bundle: .module), start: $0.at,
                     end: $0.end, url: $0.briefingURL(for: me), mine: true, event: nil)
            }
        }
        return items.sorted { $0.start < $1.start }
    }

    public func soon(now: Date) -> [Item] {
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
