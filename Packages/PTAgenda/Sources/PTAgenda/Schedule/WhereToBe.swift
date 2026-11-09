import SwiftUI
import PTCore

/// "Where I need to be" in the next 10 and the next 20 minutes, with the walk between the places: where the person is
/// now (a busy pick that is running), then each busy pick that starts within 20 minutes, with the time to leave the
/// previous place to arrive as it starts. Free picks (registration, opening night) are not places to be on time for.
/// Pure: picks, the person's busy/free choices and a time go in. Walking minutes are `DayPlanner.travelMinutes`
/// estimates (places have no coordinates), and the screen says so.
public struct WhereToBe: Equatable, Sendable {
    public enum Window: Int, Sendable {
        case next10 = 10
        case next20 = 20
    }

    /// One place to be: a session that starts within 20 minutes.
    public struct Leg: Identifiable, Equatable, Sendable {
        public let entry: NowModel.Entry
        public let window: Window
        /// The session the person comes from (the one they are in now, or the previous leg); nil when they are free.
        public let from: NowModel.Entry?
        public let walkMinutes: Int
        /// When to set off: the session's start minus the walk.
        public let leaveBy: Date
        /// Whole minutes until `leaveBy`; negative when the person is already late to leave.
        public let minutesToLeave: Int

        public var id: String { entry.id }
        public var isLate: Bool { minutesToLeave < 0 }
    }

    public let now: Date
    /// The busy pick the person is in right now (the one that started first, if two overlap).
    public let current: NowModel.Entry?
    public let legs: [Leg]

    public var next10: [Leg] { legs.filter { $0.window == .next10 } }
    public var next20: [Leg] { legs.filter { $0.window == .next20 } }
    public var isQuiet: Bool { current == nil && legs.isEmpty }

    public init(picks: [SchedulePick], now: Date, toggled: [String: ShowsAs] = [:],
                feed: (String) -> ShowsAs? = { _ in nil }) {
        self.now = now
        let busy = BusyRule.busyEntries(picks, toggled: toggled, feed: feed)
        let inNow = busy.filter { $0.isLive(at: now) }.sorted(by: NowModel.soonest).first
        current = inNow
        let horizon10 = now.addingTimeInterval(10 * 60)
        let horizon20 = now.addingTimeInterval(20 * 60)
        let upcoming = busy.filter { $0.start > now && $0.start <= horizon20 && $0.id != inNow?.id }
            .sorted(by: NowModel.soonest)

        var previous = inNow
        var legs: [Leg] = []
        for entry in upcoming {
            let walk = previous.map { DayPlanner.travelMinutes(from: $0.place, to: entry.place) } ?? 0
            let leaveBy = entry.start.addingTimeInterval(-TimeInterval(walk * 60))
            legs.append(Leg(entry: entry, window: entry.start <= horizon10 ? .next10 : .next20, from: previous,
                            walkMinutes: walk, leaveBy: leaveBy,
                            minutesToLeave: Int((leaveBy.timeIntervalSince(now) / 60).rounded(.down))))
            previous = entry
        }
        self.legs = legs
    }
}

extension BusyRule {
    /// The busy picks as entries: the person's toggle, then the event's own `shows_as`, then `feed`, then the rule.
    static func busyEntries(_ picks: [SchedulePick], toggled: [String: ShowsAs],
                            feed: (String) -> ShowsAs?) -> [NowModel.Entry] {
        picks.compactMap { pick -> NowModel.Entry? in
            guard let event = pick.event, let entry = NowModel.entry(event, pickedIDs: [pick.id], forced: true) else { return nil }
            let own = event.showsAs.flatMap(ShowsAs.init(rawValue:))
            return resolve(entry, toggled: toggled[pick.id], feed: own ?? feed(pick.id)) == .busy ? entry : nil
        }
    }
}

/// The card: where the person is now and where they need to be in the next 10 and 20 minutes, with the walk.
/// Needs the `ScheduleStore` in the environment; the Now screen and the venue map place it.
public struct WhereToBeCard: View {
    public init() {}

    @Environment(ScheduleStore.self) private var schedule
    @State private var choices = PlanChoices.shared

    public var body: some View {
        TimelineView(.everyMinute) { _ in
            let model = WhereToBe(picks: schedule.picks, now: AgendaClock.now, toggled: choices.toggled,
                                  feed: AgendaHub.showsAs)
            content(model)
        }
    }

    @ViewBuilder
    private func content(_ model: WhereToBe) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Kicker(String(localized: "Where I need to be", bundle: .module))
            if let current = model.current {
                Label(String(localized: "You are at \(current.title), \(current.place)", bundle: .module), systemImage: "mappin.circle.fill")
                    .foregroundStyle(Palette.ink)
            }
            group(String(localized: "Next 10 minutes", bundle: .module), model.next10, now: model.now)
            group(String(localized: "Next 20 minutes", bundle: .module), model.next20, now: model.now)
            if model.isQuiet {
                Text(String(localized: "Nothing in the next 20 minutes.", bundle: .module)).foregroundStyle(Palette.muted)
            } else if !model.legs.isEmpty {
                Text(String(localized: "Walking times are estimates.", bundle: .module)).font(.caption2).foregroundStyle(Palette.muted)
            }
        }
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Space.radius).fill(Palette.card))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func group(_ title: String, _ legs: [WhereToBe.Leg], now: Date) -> some View {
        if !legs.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(title).font(.caption).foregroundStyle(Palette.muted)
                ForEach(legs) { leg in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leg.entry.title).font(.headline).foregroundStyle(Palette.ink)
                        Text(leg.entry.place.isEmpty ? clock(leg.entry.start) : "\(clock(leg.entry.start)) · \(leg.entry.place)")
                            .font(.caption).foregroundStyle(Palette.muted)
                        Text(advice(leg)).font(.caption.bold()).foregroundStyle(leg.isLate ? Palette.amber : Palette.red)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func advice(_ leg: WhereToBe.Leg) -> String {
        if leg.from == nil { return String(localized: "Starts at \(clock(leg.entry.start))", bundle: .module) }
        if leg.isLate { return String(localized: "Leave now: \(-leg.minutesToLeave) min late, \(leg.walkMinutes) min walk", bundle: .module) }
        if leg.minutesToLeave == 0 { return String(localized: "Leave now, \(leg.walkMinutes) min walk", bundle: .module) }
        return String(localized: "Leave in \(leg.minutesToLeave) min, \(leg.walkMinutes) min walk", bundle: .module)
    }

    private func clock(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Lisbon.zone))
    }
}
