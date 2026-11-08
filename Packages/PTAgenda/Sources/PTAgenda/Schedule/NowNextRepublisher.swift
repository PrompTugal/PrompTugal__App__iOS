import Foundation
import PTCore

/// Keeps the widgets' and Siri's "Now and next" current: it republishes the snapshot when an agenda loads and whenever
/// the person picks or un-picks a session (spec PICK). The app makes one at launch and calls `agendaDidLoad(_:)` from
/// `AgendaHub.agendaDidLoad`; the Team app does the same through `TeamFeatures`.
@MainActor
public final class NowNextRepublisher {
    public typealias Publish = @MainActor (_ agenda: [Event], _ saved: [Event]) -> Void

    private let schedule: ScheduleStore
    private let publish: Publish
    private var agenda: [Event] = []
    private var observer: NSObjectProtocol?

    public init(schedule: ScheduleStore,
                publish: @escaping Publish = { agenda, saved in NowNextPublisher.publish(agenda: agenda, saved: saved) }) {
        self.schedule = schedule
        self.publish = publish
        observer = NotificationCenter.default.addObserver(forName: .scheduleDidChange, object: schedule, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.republish() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// An agenda loaded (or was read from the cache or the seed): remember it and publish.
    public func agendaDidLoad(_ events: [Event]) {
        agenda = events
        republish()
    }

    /// Publishes the agenda with the picks as the saved sessions. Until an agenda has arrived, the reader's own
    /// snapshot stands, so there is nothing to publish here.
    public func republish() {
        guard !agenda.isEmpty else { return }
        publish(agenda, schedule.picks.compactMap(\.event))
    }
}
