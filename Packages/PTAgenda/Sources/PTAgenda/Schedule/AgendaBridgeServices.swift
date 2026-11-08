import Foundation
import PTWeb
import PTCore

/// Gives the web bridge (PTWeb) the schedule and the reminders, as the website's JSON and plain types.
/// The meter and the identity are optional: the public app has neither.
@MainActor
public final class AgendaBridgeServices: BridgeServices {
    private let schedule: ScheduleStore
    private let reminders: ReminderScheduler
    private let identitySource: (any AgendaIdentitySource)?
    public let meter: (any BridgeMeterSource)?
    public let offersAppTopUp: Bool

    public init(schedule: ScheduleStore, reminders: ReminderScheduler, meter: (any BridgeMeterSource)?,
                identity: (any AgendaIdentitySource)?, offersAppTopUp: Bool) {
        self.schedule = schedule
        self.reminders = reminders
        self.meter = meter
        self.identitySource = identity
        self.offersAppTopUp = offersAppTopUp
    }

    // MARK: Schedule

    public func scheduleJSON() -> Data { schedule.document.encoded() }
    public func scheduleText() -> String { schedule.document.json }
    public func schedulePickIDs() -> Set<String> { Set(schedule.document.picks.map(\.id)) }

    public func mergeSchedule(data: Data, fromWeb: Bool) -> BridgeMergeResult? {
        guard let document = ScheduleDocument.decode(data) else { return nil }
        return merge(document, fromWeb: fromWeb)
    }

    public func mergeSchedule(text: String?, fromWeb: Bool) -> BridgeMergeResult {
        var document = ScheduleDocument()
        if let text, let decoded = ScheduleDocument.decode(text) { document = decoded }
        return merge(document, fromWeb: fromWeb)
    }

    private func merge(_ document: ScheduleDocument, fromWeb: Bool) -> BridgeMergeResult {
        let outcome = schedule.merge(document, from: fromWeb ? .web : .vault)
        return BridgeMergeResult(added: outcome.added.count, removed: outcome.removed.count,
                                 incomingIDs: Set(document.picks.map(\.id)))
    }

    public func lastScheduleChangeWasNotFromWeb() -> Bool {
        guard let change = schedule.lastChange else { return false }
        return change.source != .web
    }

    public func markScheduleSynced() { schedule.markSynced(.web, document: schedule.document) }

    // MARK: Identity

    public var identity: BridgeIdentity? {
        guard let id = identitySource?.currentID, let name = identitySource?.currentName else { return nil }
        return BridgeIdentity(id: id, name: name, verified: identitySource?.isVerified ?? false)
    }

    // MARK: Reminders

    public func reminderAuthorization() async -> BridgeReminderAuthorization {
        BridgeReminderAuthorization(rawValue: await reminders.currentAuthorization().rawValue) ?? .unknown
    }

    public func rescheduleReminders() async -> Int { await reminders.reschedule() }

    // MARK: Changes

    public func observeChanges(schedule onSchedule: @escaping @MainActor () -> Void,
                               pendingCredit onCredit: @escaping @MainActor () -> Void,
                               identity onIdentity: @escaping @MainActor () -> Void) -> [NSObjectProtocol] {
        let center = NotificationCenter.default
        var tokens: [NSObjectProtocol] = []
        tokens.append(center.addObserver(forName: .scheduleDidChange, object: schedule, queue: .main) { _ in
            MainActor.assumeIsolated { onSchedule() }
        })
        if let meter {
            tokens.append(center.addObserver(forName: .meterHasPendingCredit, object: meter, queue: .main) { _ in
                MainActor.assumeIsolated { onCredit() }
            })
        }
        if let identitySource {
            tokens.append(center.addObserver(forName: .teamIdentityDidChange, object: identitySource, queue: .main) { _ in
                MainActor.assumeIsolated { onIdentity() }
            })
        }
        return tokens
    }
}
