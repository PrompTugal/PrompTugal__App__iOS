import AppIntents
import Foundation

/// A summit session, for Siri and Shortcuts.
struct SessionEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Session"
    static let defaultQuery = SessionQuery()

    let id: String          // the schedule id (event slug)
    let title: String
    let when: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(when)")
    }

    @MainActor init(_ event: Event) {
        id = ScheduleID.fromPage(event.page) ?? event.page
        title = event.title
        when = "\(Lisbon.dayLabel(event.date)) · \(event.time) Lisbon"
    }
}

struct SessionQuery: EntityStringQuery {
    @MainActor private static func events() -> [Event] {
        let features = TeamFeatures.shared
        let agenda = features.planner.agenda
        return agenda.isEmpty ? features.schedule.picks.compactMap(\.event) : agenda
    }

    func entities(for identifiers: [String]) async throws -> [SessionEntity] {
        let wanted = Set(identifiers)
        return await MainActor.run {
            Self.events().filter { wanted.contains(ScheduleID.fromPage($0.page) ?? $0.page) }.map { SessionEntity($0) }
        }
    }

    func entities(matching string: String) async throws -> [SessionEntity] {
        await MainActor.run {
            Self.events().filter { $0.title.localizedStandardContains(string) || $0.place.localizedStandardContains(string) }
                .prefix(30).map { SessionEntity($0) }
        }
    }

    func suggestedEntities() async throws -> [SessionEntity] {
        await MainActor.run {
            Self.events().filter { ($0.start ?? .distantPast) > .now }.prefix(20).map { SessionEntity($0) }
        }
    }
}

/// "Save this session": adds a session to my day, as "Add to my day" does on the website.
struct SaveSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Save a session to my day"
    static let description = IntentDescription("Adds a Web Summit session to your PrompTugal day, with a reminder.")

    @Parameter(title: "Session") var session: SessionEntity

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let schedule = TeamFeatures.shared.schedule
        if schedule.isPicked(session.id) {
            return .result(dialog: "\(session.title) is already in your day.")
        }
        schedule.toggle(session.id)
        return .result(dialog: "Added \(session.title), \(session.when).")
    }
}

/// "What's next in my day": the next pick or stand-up, Lisbon time.
struct WhatsNextIntent: AppIntent {
    static let title: LocalizedStringResource = "What's next in my day"
    static let description = IntentDescription("Says your next session or team stand-up.")

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let features = TeamFeatures.shared
        let now = Date.now
        var next: [(Date, String)] = features.schedule.picks.compactMap { pick in
            guard let start = pick.start, start > now else { return nil }
            let place = pick.event?.place ?? ""
            return (start, "\(pick.title)\(place.isEmpty ? "" : ", \(place)")")
        }
        if features.identity.current != nil, let standup = features.team.upcomingStandups(after: now).first(where: { $0.at > now }) {
            next.append((standup.at, "the team stand-up"))
        }
        guard let first = next.min(by: { $0.0 < $1.0 }) else {
            return .result(dialog: "Nothing is next in your day. Add sessions from the agenda.")
        }
        return .result(dialog: "Next: \(first.1), at \(Lisbon.timeLabel(first.0)) Lisbon time.")
    }
}
