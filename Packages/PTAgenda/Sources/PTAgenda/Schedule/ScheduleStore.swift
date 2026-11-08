import Foundation
import Observation
import PTCore
import PTWeb

/// One pick in the schedule, with the event it points at when the agenda knows it.
public struct SchedulePick: Identifiable, Hashable, Sendable {
    public init(id: String, at: Date, event: Event?) {
        self.id = id
        self.at = at
        self.event = event
    }

    public let id: String          // the website's id: the event slug
    public let at: Date            // when it was picked
    public let event: Event?       // nil until the agenda (or a saved copy) has this event

    public var start: Date? { event?.start }
    public var end: Date? { event?.end }
    public var title: String { event?.title ?? id.replacingOccurrences(of: "-", with: " ") }
    public var page: String { event?.page ?? ScheduleID.page(for: id) }
    public var url: URL? { URL(string: page, relativeTo: FeedClient.site)?.absoluteURL }

    /// Sorted by event start in Lisbon time; picks with no known time go last, by title.
    public static func earlier(_ lhs: SchedulePick, _ rhs: SchedulePick) -> Bool {
        switch (lhs.event, rhs.event) {
        case let (l?, r?): return Event.earlier(l, r)
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}

extension Notification.Name {
    /// Posted on the main actor after every change to the schedule. `object` is the `ScheduleStore`.
    public static let scheduleDidChange = Notification.Name("PrompTugal.scheduleDidChange")
}

/// The one schedule (contracts §3): the website's picks and the app's saved sessions, as one list in the
/// website's `nr.schedule.v1` format, kept on this device and synced with the web view, the vault and reminders.
@MainActor @Observable
public final class ScheduleStore {
    /// Where a document came from, for the sync baseline and the bridge log.
    public enum Source: String, Codable, Sendable {
        case app, web, vault, migration
    }

    private struct Persisted: Codable {
        var state = ScheduleState()
        var events: [String: Event] = [:]                 // offline copies of picked events, by slug
        var baselines: [String: ScheduleBaseline] = [:]   // by Source.rawValue
        var savedImportedAt: Date?                        // saved.json's date when it was last imported
        var updated: Date?
    }

    public private(set) var picks: [SchedulePick] = []
    public private(set) var lastChange: (source: Source, at: Date)?
    public var storageMessage: String?

    @ObservationIgnored private var persisted = Persisted()
    @ObservationIgnored private var agendaEvents: [String: Event] = [:]
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let clock: () -> Date

    public static let fileName = "schedule.json"
    public static let legacySavedFileName = "saved.json"

    public init(directory: URL? = nil, clock: @escaping () -> Date = { .now }) {
        self.directory = directory
            ?? URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
        self.clock = clock
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            persisted = decoded
            // A time saved by an older build before the range check could crash every launch: drop it here.
            persisted.state.picks = persisted.state.picks.filter { ScheduleTime.isValid($0.value) }
            persisted.state.removed = persisted.state.removed.filter { ScheduleTime.isValid($0.value) }
        }
        importLegacySaved()
        rebuild()
    }

    // MARK: Contract API

    public var document: ScheduleDocument { persisted.state.document }

    /// Accepts the website's id (a slug) or an event page path (`events/<slug>/index.html`).
    public func isPicked(_ id: String) -> Bool {
        persisted.state.picks[Self.normalize(id)] != nil
    }

    public func toggle(_ id: String) {
        let key = Self.normalize(id)
        guard ScheduleID.isValid(key) else { return }
        persisted.state = ScheduleMerge.toggle(key, in: persisted.state, now: clock())
        commit(source: .app)
    }

    /// From a vault copy (`agenda/picks`) or anything else with no sync memory: the union, with later removals winning.
    public func merge(_ incoming: ScheduleDocument) {
        _ = merge(incoming, from: .vault)
    }

    // MARK: Sync with a source that remembers (the web view)

    /// Merges a source's document. For the web view, pass `.web`: an id the page held after the last sync and has
    /// dropped since then counts as removed on the page.
    @discardableResult
    public func merge(_ incoming: ScheduleDocument, from source: Source) -> ScheduleMerge.Outcome {
        let baseline = source == .web ? persisted.baselines[source.rawValue] : nil
        let outcome = ScheduleMerge.merge(incoming, into: persisted.state, baseline: baseline, now: clock())
        persisted.state = outcome.state
        if outcome.changed {
            commit(source: source)
        } else {
            save()
        }
        return outcome
    }

    /// Records what a source holds after a sync, so the next merge can tell its removals from our additions.
    public func markSynced(_ source: Source, document: ScheduleDocument) {
        persisted.baselines[source.rawValue] = ScheduleBaseline(ids: Set(document.picks.map(\.id)), at: clock())
        save()
    }

    public func toggle(_ event: Event) {
        if let key = ScheduleID.fromPage(event.page), persisted.state.picks[key] == nil {
            persisted.events[key] = event
        }
        toggle(event.page)
    }

    public func isPicked(_ event: Event) -> Bool { isPicked(event.page) }

    // MARK: Events

    /// Gives the store the current agenda, so picks sort by start time and keep an offline copy.
    public func updateEvents(_ agenda: [Event]) {
        var byID: [String: Event] = [:]
        for event in agenda {
            if let key = ScheduleID.fromPage(event.page) { byID[key] = event }
        }
        agendaEvents = byID
        var changed = false
        for key in persisted.state.picks.keys {
            if let fresh = byID[key], persisted.events[key] != fresh {
                persisted.events[key] = fresh
                changed = true
            }
        }
        if changed { save() }
        rebuild()
    }

    public func event(for id: String) -> Event? {
        let key = Self.normalize(id)
        return agendaEvents[key] ?? persisted.events[key]
    }

    /// Picks whose event starts on a given Lisbon day (`yyyy-MM-dd`).
    public func picks(on day: String) -> [SchedulePick] { picks.filter { $0.event?.date == day } }

    // MARK: Internals

    public static func normalize(_ id: String) -> String {
        ScheduleID.fromPage(id) ?? id
    }

    private var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    private func commit(source: Source) {
        lastChange = (source, clock())
        persisted.updated = clock()
        // keep the offline copies to the picked events only
        let picked = persisted.state.picks
        persisted.events = persisted.events.filter { picked[$0.key] != nil }
        for key in picked.keys where persisted.events[key] == nil {
            if let event = agendaEvents[key] { persisted.events[key] = event }
        }
        save()
        rebuild()
        NotificationCenter.default.post(name: .scheduleDidChange, object: self)
    }

    private func rebuild() {
        picks = persisted.state.picks.map { key, at in
            SchedulePick(id: key, at: at, event: agendaEvents[key] ?? persisted.events[key])
        }
        .sorted(by: SchedulePick.earlier)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            storageMessage = "Your schedule couldn’t be saved on this device."
        }
    }

    /// Brings the app's old Saved sessions (`saved.json`, keyed by event page) into the schedule. Runs whenever
    /// saved.json is newer than the last import, so nothing saved by an older build is lost. saved.json is kept as is.
    private func importLegacySaved() {
        let url = directory.appendingPathComponent(Self.legacySavedFileName)
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([String: Event].self, from: data) else { return }
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
            ?? clock()
        if let last = persisted.savedImportedAt, last >= modified { return }

        var incoming: [ScheduleDocument.WirePick] = []
        for (page, event) in saved {
            let key = ScheduleID.fromPage(event.page) ?? ScheduleID.fromPage(page) ?? Self.legacyID(page)
            guard ScheduleID.isValid(key) else { continue }
            incoming.append(.init(id: key, at: modified))
            persisted.events[key] = event
        }
        let outcome = ScheduleMerge.merge(ScheduleDocument(picks: incoming), into: persisted.state, now: clock())
        persisted.state = outcome.state
        persisted.savedImportedAt = modified
        lastChange = (.migration, clock())
        save()
    }

    /// A saved page that is not an event page keeps its path, made safe as an id (no slashes).
    public static func legacyID(_ page: String) -> String {
        page.replacingOccurrences(of: "/index.html", with: "").replacingOccurrences(of: "/", with: "-")
    }
}
