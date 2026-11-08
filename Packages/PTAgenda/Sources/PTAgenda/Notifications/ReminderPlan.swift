import Foundation
import PTCore
import PTWeb

/// One local notification to schedule.
public struct ReminderItem: Identifiable, Hashable, Sendable {
    public init(id: String, kind: Kind, title: String, body: String, fire: Date, start: Date, url: URL?, scheme: String = AppLinks.scheme) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.fire = fire
        self.start = start
        self.url = url
        self.scheme = scheme
    }

    public enum Kind: String, Sendable { case pick, standup }

    public let id: String              // "pt.pick.<slug>" or "pt.standup.<slot>": also the notification's identifier
    public let kind: Kind
    public let title: String
    public let body: String
    public let fire: Date
    public let start: Date
    public let url: URL?
    /// The URL scheme of the app that schedules it (`AppLinks.scheme`: `promptugal` for the public app, `ptteam` for the Team app).
    public var scheme: String

    /// The link a tap opens inside the app, through the shell's `<scheme>://open/<destination>` route. It lands on
    /// My day today; the query names the session or briefing so the shell can open it directly.
    public var appLink: URL {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "open"
        parts.path = "/team.schedule"
        switch kind {
        case .pick:
            parts.queryItems = [URLQueryItem(name: "session", value: String(id.dropFirst("\(ReminderPlan.prefix)pick.".count)))]
        case .standup:
            parts.queryItems = url.map { [URLQueryItem(name: "url", value: $0.absoluteString)] }
        }
        return parts.url ?? URL(string: "\(scheme)://open/team.schedule")!
    }
}

/// Which reminders to schedule, worked out without touching the notification centre, so it can be tested.
public enum ReminderPlan {
    /// iOS keeps at most 64 pending local notifications per app. The plan uses 60 and leaves 4 spare.
    public static let limit = 60
    public static let prefix = "pt."

    public static func items(picks: [SchedulePick], standups: [TeamStandup], person: String?, leadMinutes: Int,
                      now: Date, includePicks: Bool = true, includeStandups: Bool = true,
                      scheme: String = AppLinks.scheme, limit: Int = ReminderPlan.limit) -> [ReminderItem] {
        let lead = TimeInterval(max(0, leadMinutes) * 60)
        var items: [ReminderItem] = []
        if includePicks {
            for pick in picks {
                guard let start = pick.start, start > now else { continue }
                let fire = start.addingTimeInterval(-lead)
                guard fire > now else { continue }
                let place = pick.event?.place ?? ""
                items.append(ReminderItem(
                    id: "\(prefix)pick.\(pick.id)", kind: .pick, title: pick.title,
                    body: [String(localized: "Starts \(Lisbon.timeLabel(start)) Lisbon time", bundle: .module), place].filter { !$0.isEmpty }.joined(separator: " · "),
                    fire: fire, start: start, url: pick.url, scheme: scheme))
            }
        }
        if includeStandups, let person, !person.isEmpty {
            for standup in standups where standup.at > now {
                let fire = standup.at.addingTimeInterval(-lead)
                guard fire > now else { continue }
                items.append(ReminderItem(
                    id: "\(prefix)standup.\(standup.slot)", kind: .standup, title: String(localized: "Stand-up at \(Lisbon.timeLabel(standup.at))", bundle: .module),
                    body: String(localized: "Lisbon time. Your briefing is ready.", bundle: .module), fire: fire, start: standup.at,
                    url: standup.briefingURL(for: person), scheme: scheme))
            }
        }
        return Array(items.sorted { $0.fire == $1.fire ? $0.id < $1.id : $0.fire < $1.fire }.prefix(max(0, limit)))
    }

    /// The fire time as calendar components in Lisbon time, for `UNCalendarNotificationTrigger`.
    public static func components(_ date: Date) -> DateComponents {
        var parts = Lisbon.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        parts.timeZone = Lisbon.zone
        parts.calendar = Lisbon.calendar
        return parts
    }
}
