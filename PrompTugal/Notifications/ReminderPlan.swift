import Foundation

/// One local notification to schedule.
struct ReminderItem: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable { case pick, standup }

    let id: String              // "pt.pick.<slug>" or "pt.standup.<slot>": also the notification's identifier
    let kind: Kind
    let title: String
    let body: String
    let fire: Date
    let start: Date
    let url: URL?
}

/// Which reminders to schedule, worked out without touching the notification centre, so it can be tested.
enum ReminderPlan {
    /// iOS keeps at most 64 pending local notifications per app. The plan uses 60 and leaves 4 spare.
    static let limit = 60
    static let prefix = "pt."

    static func items(picks: [SchedulePick], standups: [TeamStandup], person: String?, leadMinutes: Int,
                      now: Date, includePicks: Bool = true, includeStandups: Bool = true,
                      limit: Int = ReminderPlan.limit) -> [ReminderItem] {
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
                    body: ["Starts \(Lisbon.timeLabel(start)) Lisbon time", place].filter { !$0.isEmpty }.joined(separator: " · "),
                    fire: fire, start: start, url: pick.url))
            }
        }
        if includeStandups, let person, !person.isEmpty {
            for standup in standups where standup.at > now {
                let fire = standup.at.addingTimeInterval(-lead)
                guard fire > now else { continue }
                items.append(ReminderItem(
                    id: "\(prefix)standup.\(standup.slot)", kind: .standup, title: "Stand-up at \(Lisbon.timeLabel(standup.at))",
                    body: "Lisbon time. Your briefing is ready.", fire: fire, start: standup.at,
                    url: standup.briefingURL(for: person)))
            }
        }
        return Array(items.sorted { $0.fire == $1.fire ? $0.id < $1.id : $0.fire < $1.fire }.prefix(max(0, limit)))
    }

    /// The fire time as calendar components in Lisbon time, for `UNCalendarNotificationTrigger`.
    static func components(_ date: Date) -> DateComponents {
        var parts = Lisbon.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        parts.timeZone = Lisbon.zone
        parts.calendar = Lisbon.calendar
        return parts
    }
}
