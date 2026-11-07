import Foundation
import Observation

/// Feeds `DayPlanner` and turns accepted proposals into picks. Coordination comes from the data the team publishes:
/// each person's command centre (`people/<id>/app/data.json`, `event.sessions`) lists the summit sessions picked
/// for them. Later, teammates' own picks come from their vaults (contracts §5).
@MainActor @Observable
final class PlannerStore {
    var day: String
    var preferences = DayPlanner.Preferences()
    private(set) var agenda: [Event] = []
    private(set) var loadingTeam = false

    @ObservationIgnored private let schedule: ScheduleStore
    @ObservationIgnored private let team: TeamStore
    @ObservationIgnored private let identity: TeamIdentityStore
    // Caches, so a redraw does not redo the work (195 agenda items, nine command centres).
    @ObservationIgnored private var titleKeywords: [String: Set<String>] = [:]
    @ObservationIgnored private var coordinationCache: (key: String, value: ([String: String], [String: [String]]))?
    @ObservationIgnored private var planCache: (key: String, value: DayPlanner.Plan)?

    /// The summit days, Lisbon time.
    static let summitDays = ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12"]

    init(schedule: ScheduleStore, team: TeamStore, identity: TeamIdentityStore) {
        self.schedule = schedule
        self.team = team
        self.identity = identity
        let today = Lisbon.day(.now)
        day = Self.summitDays.contains(today) ? today : Self.summitDays[1]
    }

    func updateAgenda(_ events: [Event]) {
        agenda = events
        titleKeywords = DayPlanner.keywordIndex(events)
        coordinationCache = nil
        planCache = nil
    }

    var days: [String] {
        let fromAgenda = Set(agenda.map(\.date))
        return fromAgenda.isEmpty ? Self.summitDays : fromAgenda.sorted()
    }

    var plan: DayPlanner.Plan {
        let picks = schedule.picks
        let standups = identity.current == nil ? [] : team.standups
        let key = [day, preferences.dayStart, preferences.dayEnd, "\(preferences.officialOnly)",
                   "\(preferences.minimumGapMinutes)", coordinationKey,
                   picks.map { "\($0.id)@\($0.event?.time ?? "")" }.joined(separator: ","),
                   standups.map(\.slot).joined(separator: ",")].joined(separator: "|")
        if let cached = planCache, cached.key == key { return cached.value }
        var prefs = preferences
        let (suggested, teammates) = coordination()
        prefs.suggested.merge(suggested) { a, _ in a }
        prefs.teammates.merge(teammates) { a, _ in a }
        let plan = DayPlanner.plan(day: day, agenda: agenda, picks: picks, standups: standups, preferences: prefs,
                                   titleKeywords: titleKeywords)
        planCache = (key, plan)
        return plan
    }

    /// Every agenda session on a day that teammates have, with who: "where is everyone".
    func teamSessions(on day: String) -> [(event: Event, people: [String])] {
        let going = coordination().1
        return agenda.filter { $0.date == day }.compactMap { event in
            guard let id = ScheduleID.fromPage(event.page), let people = going[id], !people.isEmpty else { return nil }
            return (event, people)
        }
        .sorted { Event.earlier($0.event, $1.event) }
    }

    /// Teammates who have a given event in their command centre, by name.
    func teammates(for eventID: String) -> [String] { coordination().1[eventID] ?? [] }

    /// Accepting a proposal picks it, like "Add to my day" on the website.
    func accept(_ proposals: [DayPlanner.Proposal]) {
        for proposal in proposals {
            if let id = proposal.item.eventID, !schedule.isPicked(id) {
                if let event = agenda.first(where: { ScheduleID.fromPage($0.page) == id }) {
                    schedule.toggle(event)
                } else {
                    schedule.toggle(id)
                }
            }
        }
    }

    /// Loads every teammate's command centre, so their sessions show in the plan.
    func loadTeam() async {
        guard !loadingTeam else { return }
        loadingTeam = true
        defer { loadingTeam = false }
        let ids = team.me?.people.map(\.id) ?? TeamPerson.order
        for id in ids { await team.refreshCentre(for: id) }
    }

    /// What the coordination depends on: the agenda, each loaded command centre's build, and who I am.
    private var coordinationKey: String {
        let centres = team.centres.map { "\($0.key):\($0.value.builtAt)" }.sorted().joined(separator: ",")
        return "\(agenda.count)|\(identity.current?.id ?? "")|\(team.me?.builtAt ?? "")|\(centres)"
    }

    /// (sessions suggested for me → reason, sessions teammates have → their first names), cached.
    private func coordination() -> ([String: String], [String: [String]]) {
        let key = coordinationKey
        if let cached = coordinationCache, cached.key == key { return cached.value }
        let value = buildCoordination()
        coordinationCache = (key, value)
        return value
    }

    private func buildCoordination() -> ([String: String], [String: [String]]) {
        let byTitle = Dictionary(agenda.compactMap { event -> (String, String)? in
            guard let id = ScheduleID.fromPage(event.page) else { return nil }
            return (Self.normalize(event.title), id)
        }, uniquingKeysWith: { a, _ in a })
        let me = identity.current?.id
        var suggested: [String: String] = [:]
        var teammates: [String: [String]] = [:]
        for (person, centre) in team.centres.sorted(by: { $0.key < $1.key }) {
            let name = team.me?.person(person)?.first ?? centre.person.name.split(separator: " ").first.map(String.init) ?? person
            for session in centre.sessions {
                guard let id = byTitle[Self.normalize(session.title)] else { continue }
                if person == me {
                    suggested[id] = session.whyRelevant.isEmpty ? "Picked for you by the team"
                        : "For you: \(session.whyRelevant.prefix(90))"
                } else if !(teammates[id]?.contains(name) ?? false) {
                    teammates[id, default: []].append(name)
                }
            }
        }
        return (suggested, teammates)
    }

    static func normalize(_ title: String) -> String {
        title.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
