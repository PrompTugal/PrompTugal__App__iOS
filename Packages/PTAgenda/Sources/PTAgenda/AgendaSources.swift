import Foundation
import SwiftUI
import PTCore
import PTWeb

// What the schedule, the planner and the reminders need from the team data and the vault, as small protocols.
// The Team app conforms its stores (`TeamStore`, `TeamIdentityStore`, `VaultSession`); the public app passes nil.
// The app also sets `AgendaHub` once at launch.

/// The team site. The stand-up links are built from it.
public enum TeamSite {
    public static let base = URL(string: "https://web-summit.sgit.ai/")!
}

/// A team stand-up (https://web-summit.sgit.ai/meetings/index.md and /meetings/<slot>/<person>/).
public struct TeamStandup: Identifiable, Hashable, Sendable {
    public let slot: String                // "2026-11-07-1200"
    public let at: Date                    // Lisbon time (UTC in November)
    public var id: String { slot }
    public var url: URL { TeamSite.base.appendingPathComponent("meetings/\(slot)/index.html") }
    public func briefingURL(for person: String) -> URL {
        TeamSite.base.appendingPathComponent("meetings/\(slot)/\(person)/index.html")
    }
    /// The stand-ups last about 30 minutes; the site does not say.
    public var end: Date { at.addingTimeInterval(30 * 60) }

    /// - Parameters:
    ///   - slot: the folder name, "2026-11-05-1300".
    ///   - label: the list's link text, "2026-11-05 12:00". It wins over the slot: the team moved the
    ///     13:00 stand-up to 12:00 on 5 November and kept some folder names.
    public init?(slot: String, label: String? = nil) {
        let parts = slot.split(separator: "-")
        guard parts.count == 4, parts[3].count == 4 else { return nil }
        let fromSlot = Lisbon.instant(day: parts[0...2].joined(separator: "-"),
                                      clock: "\(parts[3].prefix(2)):\(parts[3].suffix(2))")
        let labelParts = (label ?? "").split(separator: " ")
        let fromLabel = labelParts.count == 2 ? Lisbon.instant(day: String(labelParts[0]), clock: String(labelParts[1])) : nil
        guard let at = fromLabel ?? fromSlot else { return nil }
        self.slot = slot
        self.at = at
    }
}

extension Notification.Name {
    /// Posted when the chosen or verified team identity changes. `object` is the identity store.
    public static let teamIdentityDidChange = Notification.Name("PrompTugal.teamIdentityDidChange")
    /// Posted when the team's stand-ups change.
    public static let teamStandupsDidChange = Notification.Name("PrompTugal.teamStandupsDidChange")
}

/// One session in a teammate's command centre, for the planner.
public struct AgendaCentreSession: Sendable {
    public let person: String           // the teammate's id
    public let name: String             // first name to show
    public let title: String
    public let whyRelevant: String
    public init(person: String, name: String, title: String, whyRelevant: String) {
        self.person = person
        self.name = name
        self.title = title
        self.whyRelevant = whyRelevant
    }
}

/// Who the person is, when the app has a team identity.
@MainActor
public protocol AgendaIdentitySource: AnyObject {
    var currentID: String? { get }
    var currentName: String? { get }
    var isVerified: Bool { get }
}

/// The team's stand-ups and each teammate's picked sessions.
@MainActor
public protocol AgendaTeamSource: AnyObject {
    var standups: [TeamStandup] { get }
    func upcomingStandups(after now: Date) -> [TeamStandup]
    func refresh(person: String?) async
    /// Changes whenever the team data the planner reads changes (the "me" build and each loaded command centre).
    var dataVersion: String { get }
    /// Loads every teammate's command centre.
    func loadEveryone() async
    /// Every session in the loaded command centres, ordered by person id.
    func centreSessions() -> [AgendaCentreSession]
}

/// The reader's vault, as far as the schedule needs it.
@MainActor
public protocol VaultPicksAccess: AnyObject {
    /// A reader vault is open on this device.
    var hasVault: Bool { get }
    /// It was opened with its vault key and an access token is set, so saving can work.
    var canSave: Bool { get }
    /// The id of the open vault, read inside observation tracking so a change pulls the picks again.
    var openVaultID: String? { get }
    func loadPicks() async throws -> Data?
    func savePicks(_ local: Data) async throws -> Data
}

private struct AgendaTeamKey: EnvironmentKey {
    static let defaultValue: (any AgendaTeamSource)? = nil
}

private struct AgendaIdentityKey: EnvironmentKey {
    static let defaultValue: (any AgendaIdentitySource)? = nil
}

extension EnvironmentValues {
    /// The team data, or nil in an app with no team.
    public var agendaTeam: (any AgendaTeamSource)? {
        get { self[AgendaTeamKey.self] }
        set { self[AgendaTeamKey.self] = newValue }
    }

    /// The team identity, or nil in an app with no team.
    public var agendaIdentity: (any AgendaIdentitySource)? {
        get { self[AgendaIdentityKey.self] }
        set { self[AgendaIdentityKey.self] = newValue }
    }
}

/// The few things `ReaderStore` needs from the app. The app sets them once at launch.
@MainActor
public enum AgendaHub {
    /// The one schedule.
    public static var schedule: ScheduleStore?
    /// The agenda was loaded (or read from the cache): give it to the schedule, the planner and the widgets.
    public static var agendaDidLoad: ([Event]) -> Void = { _ in }
    /// Publish "Now and next" with the saved sessions, when there is no agenda yet.
    public static var publishNowNext: (_ agenda: [Event], _ saved: [Event]) -> Void = { _, _ in }
    /// The agenda built into the app, read when nothing has been cached yet, so the first launch works with no
    /// network at the venue. The app sets it at launch (the core pack of PTSync); the default has none.
    public static var seedAgenda: () -> [Event] = { [] }
    /// A second source for `shows_as` by schedule id, for an app that has it somewhere other than the event (the picks'
    /// own copy of the event carries the feed's `shows_as` already, and is read first). Main-actor: My program reads it
    /// from the screen; the day planner (nonisolated) reads only the event's own field. The default has none.
    public static var showsAs: (_ id: String) -> ShowsAs? = { _ in nil }
}
