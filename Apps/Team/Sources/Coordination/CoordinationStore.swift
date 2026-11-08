import Foundation
import Observation

/// "Where is everyone": my plan and the plans teammates share through their vaults.
///
/// What works without keys: the team list (web-summit.sgit.ai `me.json`) and my own picks. Each teammate's
/// picks need the read key of their vault, which they share once; the app keeps it behind Face ID through the
/// vault session and remembers here only which vault id belongs to which person (never a key).
@MainActor @Observable
final class CoordinationStore {
    static let shared: CoordinationStore = { TeamLanesWiring.install(); return CoordinationStore() }()
    static let picksPath = "apps/agenda/picks.json"

    struct Person: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let colour: String?
    }

    private(set) var people: [Person] = []
    private(set) var plans: [String: TeammatePlan] = [:]
    private(set) var errors: [String: String] = [:]
    private(set) var events: [Event] = []
    private(set) var loading = false
    private(set) var lastShare: Date?
    private(set) var message: String?
    var day: String = ""

    /// person id → vault id, for teammates whose read key is on this device.
    private(set) var linkedVaults: [String: String] {
        didSet { defaults.set(linkedVaults, forKey: Self.linksKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    static let linksKey = "collab.teamVaults.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        linkedVaults = defaults.dictionary(forKey: Self.linksKey) as? [String: String] ?? [:]
    }

    var me: CollabIdentity? { CollabHooks.me() }
    var vaultAvailable: Bool { CollabHooks.vault != nil }
    var vaultOpen: Bool { CollabHooks.vault?.isOpen ?? false }

    var analysis: CoordinationAnalysis {
        CoordinationAnalysis.build(plans: Array(plans.values), events: events, day: day)
    }

    var days: [String] {
        let all = Set(events.map(\.date)).sorted()
        return all.isEmpty ? [Lisbon.day(.now)] : all
    }

    func name(_ person: String) -> String {
        people.first { $0.id == person }?.name ?? plans[person]?.name ?? person
    }

    // MARK: Loading

    func load() async {
        loading = true
        defer { loading = false }
        events = await CollabHooks.agenda()
        if day.isEmpty || !days.contains(day) {
            let today = Lisbon.day(.now)
            day = days.first { $0 >= today } ?? days.first ?? today
        }
        await loadPeople()
        loadMine()
        await loadTeammates()
    }

    /// The team list from the team session's store (me.json), so there is one set of team models.
    func loadPeople() async {
        let team = TeamFeatures.shared.team
        if team.me == nil { await team.refresh(person: me?.id) }
        guard let everyone = team.me?.people else { return }
        people = everyone.map { Person(id: $0.id, name: $0.name, colour: $0.colour) }
    }

    func loadMine() {
        let id = me?.id ?? "me"
        plans[id] = TeammatePlan(person: id, name: me?.name ?? "Me", source: .me,
                                 pickIds: CollabHooks.myPickIds(), loadedAt: .now)
    }

    func loadTeammates() async {
        guard let vault = CollabHooks.vault else { return }
        for (person, vaultId) in linkedVaults where person != me?.id {
            do {
                if let data = try await vault.read(Self.picksPath, vaultId: vaultId) {
                    plans[person] = TeammatePlan(person: person, name: name(person), source: .vault(vaultId),
                                                 pickIds: PickId.ids(inScheduleDocument: data), loadedAt: .now)
                    errors[person] = nil
                } else {
                    errors[person] = "No picks in their vault yet."
                }
            } catch {
                errors[person] = CollabErrorText.short(error)
            }
        }
    }

    // MARK: Keys and sharing

    /// A teammate's read key, pasted or scanned. The key goes to the vault session (Keychain, Face ID); only the
    /// vault id is kept here.
    func link(person: String, readKey: String) async {
        guard let vault = CollabHooks.vault else {
            message = CollabHooks.HookError.noVault.localizedDescription
            return
        }
        do {
            let vaultId = try await vault.openShared(readKey: readKey, label: "\(name(person))'s plan")
            linkedVaults[person] = vaultId
            message = "Linked \(name(person))'s vault."
            await loadTeammates()
        } catch {
            message = CollabErrorText.short(error)
        }
    }

    func unlink(person: String) {
        linkedVaults[person] = nil
        plans[person] = nil
        errors[person] = nil
    }

    /// "Share my plan": my picks into my vault (`apps/agenda/picks.json`, merged as the website merges).
    /// Teammates with my read key then see them.
    func shareMyPlan() async {
        guard let vault = CollabHooks.vault, vault.canWrite else {
            message = CollabHooks.HookError.noWritableVault.localizedDescription
            return
        }
        do {
            let document = try PickId.scheduleDocument(ids: CollabHooks.myPickIds())
            let merged = try await vault.savePicks(document)
            lastShare = .now
            message = "Shared \(PickId.ids(inScheduleDocument: merged).count) picks to your vault."
        } catch {
            message = CollabErrorText.short(error)
        }
    }

    /// For the AI: who is where on `day`, as text.
    func summary(for day: String) -> String {
        let result = CoordinationAnalysis.build(plans: Array(plans.values), events: events, day: day)
        var lines = ["Team plans on \(Lisbon.dayLabel(day)) (\(plans.count) people with plans):"]
        for item in result.together {
            lines.append("- Together: \(item.event.time) \(item.event.title) at \(item.event.place): \(item.people.map { name($0) }.joined(separator: ", "))")
        }
        for clash in result.clashes {
            lines.append("- Clash for \(name(clash.person)): \(clash.first.time) \(clash.first.title) and \(clash.second.time) \(clash.second.title)")
        }
        return lines.joined(separator: "\n")
    }
}
