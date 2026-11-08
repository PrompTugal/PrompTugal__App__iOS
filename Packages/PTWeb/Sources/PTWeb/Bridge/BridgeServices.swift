import Foundation
import SwiftUI
import PTCore

/// What the bridge needs from the app, in plain types. PTWeb cannot see the schedule, the reading meter, the team
/// identity or the reminders, which live above it. The app (or PTAgenda's `AgendaBridgeServices`) supplies them.
/// The schedule travels as the website's JSON, so no schedule type crosses the package line.

public struct BridgeMergeResult: Sendable {
    public var added: Int
    public var removed: Int
    /// The picks that were on the page (or in the vault), before the merge.
    public var incomingIDs: Set<String>
    public init(added: Int, removed: Int, incomingIDs: Set<String>) {
        self.added = added
        self.removed = removed
        self.incomingIDs = incomingIDs
    }
}

/// App Store credit waiting to be written into the website's meter.
public struct BridgeCredit: Hashable, Sendable {
    public let reference: String
    public let pence: Int
    public init(reference: String, pence: Int) {
        self.reference = reference
        self.pence = pence
    }
}

public struct BridgeIdentity: Hashable, Sendable {
    public let id: String
    public let name: String
    public let verified: Bool
    public init(id: String, name: String, verified: Bool) {
        self.id = id
        self.name = name
        self.verified = verified
    }
}

public enum BridgeReminderAuthorization: String, Sendable { case unknown, allowed, denied }

/// The reading meter, as the bridge sees it. `MeterStore` (Team app) conforms.
@MainActor
public protocol BridgeMeterSource: AnyObject {
    func update(from summary: [String: Any]?)
    /// "balance 120p" style text for the log, nil when there is no meter yet.
    var balanceText: String? { get }
    var bridgeCredits: [BridgeCredit] { get }
    func markCredited(reference: String)
}

extension Notification.Name {
    /// Posted (object: the meter) when App Store credit is waiting to be written into the website's meter.
    public static let meterHasPendingCredit = Notification.Name("PrompTugal.meterHasPendingCredit")
}

@MainActor
public protocol BridgeServices: AnyObject {
    /// Whether the app offers its own top-up (guideline 3.1.1): Debug builds of the Team app only.
    var offersAppTopUp: Bool { get }

    // Schedule, as the website's JSON.
    func scheduleJSON() -> Data
    func scheduleText() -> String
    func schedulePickIDs() -> Set<String>
    /// Merges the page's (or vault's) schedule. `nil` data or text, or text that does not decode, merges an empty
    /// document. Returns nil only when `data` is given and is not a schedule.
    func mergeSchedule(data: Data, fromWeb: Bool) -> BridgeMergeResult?
    func mergeSchedule(text: String?, fromWeb: Bool) -> BridgeMergeResult
    /// True when the latest change to the schedule did not come from a web page.
    func lastScheduleChangeWasNotFromWeb() -> Bool
    func markScheduleSynced()

    // Meter.
    var meter: (any BridgeMeterSource)? { get }

    // Team identity.
    var identity: BridgeIdentity? { get }

    // Reminders.
    func reminderAuthorization() async -> BridgeReminderAuthorization
    func rescheduleReminders() async -> Int

    /// Registers the three change callbacks and returns the observers to keep alive.
    func observeChanges(schedule: @escaping @MainActor () -> Void,
                        pendingCredit: @escaping @MainActor () -> Void,
                        identity: @escaping @MainActor () -> Void) -> [NSObjectProtocol]
}

/// Where the web views find the bridge and the few app screens they open. The app sets these once at launch
/// (`TeamFeatures` in the Team app).
@MainActor
public enum WebBridgeHub {
    public static var bridge: AppBridge?
    /// The offline reader the website browser opens in a sheet. Nil: no reader.
    public static var offlineReader: (() -> AnyView)?
    /// A page finished loading: the title and URL, for "current page" context in Ask.
    public static var noteCurrentPage: (_ title: String, _ url: URL?) -> Void = { _, _ in }
}
