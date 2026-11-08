import Foundation
import Observation

/// The team site's public data, fetched and kept on the device for offline use (contracts §6).
/// Each source is cached as the bytes the site served, so a newer app reads an older cache the same way.
@MainActor @Observable
final class TeamStore {
    enum Source: String, CaseIterable, Sendable {
        case me, meetings, wakes, reports, pulse, log

        var url: URL {
            switch self {
            case .me: TeamEndpoints.me
            case .meetings: TeamEndpoints.meetings
            case .wakes: TeamEndpoints.wakes
            case .reports: TeamEndpoints.reports
            case .pulse: TeamEndpoints.pulse
            case .log: TeamEndpoints.log
            }
        }
    }

    struct SourceStatus: Sendable, Hashable {
        var updated: Date?
        var bytes = 0
        var failed = false
    }

    typealias Fetch = @Sendable (URL) async throws -> Data

    private(set) var me: TeamMe?
    private(set) var centres: [String: CommandCentre] = [:]       // by person id
    private(set) var standups: [TeamStandup] = []
    private(set) var standupSummaries: [StandupSummary] = []       // the list's open counts, by time
    private(set) var agendas: [String: StandupAgenda] = [:]        // by stand-up slot, loaded on demand
    private(set) var wakes: [AgentWakes] = []
    private(set) var reports: [TeamReport] = []
    private(set) var pulse: [PulseEntry] = []
    private(set) var log: [SessionLogEntry] = []
    private(set) var status: [String: SourceStatus] = [:]          // by Source.rawValue or "centre.<id>"
    private(set) var refreshing = false

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let fetch: Fetch

    init(directory: URL? = nil, fetch: Fetch? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory
            .appendingPathComponent("PrompTugal/team", isDirectory: true)
        self.fetch = fetch ?? TeamStore.urlSessionFetch
        for source in Source.allCases { if let data = cached(source.rawValue) { apply(source, data) } }
        for file in (try? FileManager.default.contentsOfDirectory(atPath: self.directory.path)) ?? []
        where file.hasPrefix("centre.") {
            let key = String(file.dropLast(file.hasSuffix(".cache") ? 6 : 0))
            if let data = cached(key), let centre = try? JSONDecoder().decode(CommandCentre.self, from: data) {
                centres[centre.person.id] = centre
            }
        }
        for file in (try? FileManager.default.contentsOfDirectory(atPath: self.directory.path)) ?? []
        where file.hasPrefix("agenda.") {
            let key = String(file.dropLast(file.hasSuffix(".cache") ? 6 : 0))
            if let data = cached(key) { applyAgenda(key, data) }
        }
    }

    // MARK: Reading

    /// Stand-ups still to come (or running), soonest first.
    func upcomingStandups(after now: Date = .now) -> [TeamStandup] {
        standups.filter { $0.end > now }
    }

    func centre(for person: String) -> CommandCentre? { centres[person] }

    func agenda(for slot: String) -> StandupAgenda? { agendas[slot] }

    // MARK: Refreshing

    func refresh(person: String? = nil) async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        await withTaskGroup(of: (String, Result<Data, Error>).self) { group in
            for source in Source.allCases {
                let url = source.url, fetch = self.fetch
                group.addTask { (source.rawValue, await Result { try await fetch(url) }) }
            }
            if let person, TeamPerson.order.contains(person) || me?.person(person) != nil {
                let url = TeamEndpoints.base.appendingPathComponent("people/\(person)/app/data.json"), fetch = self.fetch
                group.addTask { ("centre.\(person)", await Result { try await fetch(url) }) }
            }
            for await (key, result) in group { receive(key, result) }
        }
    }

    func refreshCentre(for person: String) async {
        guard ScheduleID.isValid(person) else { return }
        let url = TeamEndpoints.base.appendingPathComponent("people/\(person)/app/data.json")
        do {
            receive("centre.\(person)", .success(try await fetch(url)))
        } catch {
            receive("centre.\(person)", .failure(error))
        }
    }

    /// One stand-up's agenda (`/meetings/<slot>/index.md`), for the native stand-up screen.
    func refreshAgenda(slot: String) async {
        guard TeamStore.isValidSlot(slot), let url = TeamEndpoints.url("meetings/\(slot)/index.md") else { return }
        do {
            receive("agenda.\(slot)", .success(try await fetch(url)))
        } catch {
            receive("agenda.\(slot)", .failure(error))
        }
    }

    /// "2026-11-08-1200": digits and dashes only, and a real stand-up time, since it goes into a URL and a file name.
    nonisolated static func isValidSlot(_ slot: String) -> Bool {
        slot.count == 15 && slot.allSatisfy { $0.isNumber || $0 == "-" } && TeamStandup(slot: slot) != nil
    }

    private func receive(_ key: String, _ result: Result<Data, Error>) {
        switch result {
        case .success(let data):
            let ok: Bool
            if let source = Source(rawValue: key) {
                ok = apply(source, data)
            } else if key.hasPrefix("centre."), let centre = try? JSONDecoder().decode(CommandCentre.self, from: data) {
                centres[centre.person.id.isEmpty ? String(key.dropFirst(7)) : centre.person.id] = centre
                ok = true
            } else if key.hasPrefix("agenda.") {
                ok = applyAgenda(key, data)
            } else {
                ok = false
            }
            if ok { store(key, data) }
            status[key] = SourceStatus(updated: ok ? .now : status[key]?.updated, bytes: data.count, failed: !ok)
        case .failure:
            var current = status[key] ?? SourceStatus()
            current.failed = true
            status[key] = current
        }
    }

    @discardableResult
    private func apply(_ source: Source, _ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self)
        switch source {
        case .me:
            guard let decoded = try? JSONDecoder().decode(TeamMe.self, from: data), !decoded.people.isEmpty else { return false }
            me = decoded
        case .meetings:
            let parsed = TeamMarkdown.standups(text)
            guard !parsed.isEmpty else { return false }
            standups = parsed
            standupSummaries = TeamMarkdown.standupSummaries(text)
            NotificationCenter.default.post(name: .teamStandupsDidChange, object: self)
        case .wakes:
            wakes = TeamMarkdown.wakes(text)
        case .reports:
            reports = TeamMarkdown.reports(text)
        case .pulse:
            pulse = TeamMarkdown.pulse(text)
        case .log:
            log = TeamMarkdown.log(text)
        }
        return true
    }

    @discardableResult
    private func applyAgenda(_ key: String, _ data: Data) -> Bool {
        let slot = String(key.dropFirst("agenda.".count))
        let text = String(decoding: data, as: UTF8.self)
        guard TeamStore.isValidSlot(slot), text.contains("# Stand-up") else { return false }
        agendas[slot] = TeamMarkdown.agenda(text, slot: slot)
        return true
    }

    // MARK: Cache

    private func fileURL(_ key: String) -> URL { directory.appendingPathComponent("\(key).cache") }

    private func cached(_ key: String) -> Data? {
        let url = fileURL(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        status[key] = SourceStatus(updated: modified, bytes: data.count, failed: false)
        return data
    }

    private func store(_ key: String, _ data: Data) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Through the app's shared `HTTPClient` (Q8), so every team request shows in Debug → Network with its size and
    /// time. Labelled by file: "team.me", "team.meetings", "team.data.silvio", …
    static let urlSessionFetch: Fetch = { url in
        try await HTTPClient.shared.get(url, timeout: 20, label: TeamStore.label(for: url))
    }

    nonisolated static func label(for url: URL) -> String {
        let parts = url.pathComponents.filter { $0 != "/" }
        if parts.count >= 4, parts[0] == "people", parts.last == "data.json" { return "team.data.\(parts[1])" }
        let name = parts.last.map { ($0 as NSString).deletingPathExtension } ?? "team"
        return "team." + (name == "index" ? (parts.dropLast().last ?? "index") : name)
    }
}

private extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
