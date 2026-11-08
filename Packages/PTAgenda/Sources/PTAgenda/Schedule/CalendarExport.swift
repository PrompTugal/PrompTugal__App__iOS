import EventKit
import Foundation
import PTCore
import PTWeb

/// "Add to Calendar" (brief 03): writes picks to the iOS calendar, only when the person asks, with write-only access
/// (iOS 17+), so the app never reads their calendar. Each event carries the session's link in its URL and notes.
@MainActor
public enum CalendarExport {
    public enum Outcome: Equatable {
        case added(Int)
        case denied
        case failed(String)
    }

    /// Needs `NSCalendarsWriteOnlyAccessUsageDescription` in Info (platform).
    public static func add(_ picks: [SchedulePick], store: EKEventStore = EKEventStore()) async -> Outcome {
        let timed = picks.filter { $0.start != nil }
        guard !timed.isEmpty else { return .added(0) }
        do {
            guard try await store.requestWriteOnlyAccessToEvents() else { return .denied }
        } catch {
            return .denied
        }
        guard let calendar = store.defaultCalendarForNewEvents else { return .failed("No calendar to add to.") }
        var added = 0
        for pick in timed {
            guard let start = pick.start else { continue }
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = pick.title
            event.startDate = start
            event.endDate = pick.end ?? start.addingTimeInterval(30 * 60)
            event.timeZone = Lisbon.zone
            event.location = pick.event?.place
            event.url = pick.url
            event.notes = ["From PrompTugal · Lisbon 2026", pick.url?.absoluteString ?? ""]
                .filter { !$0.isEmpty }.joined(separator: "\n")
            do {
                try store.save(event, span: .thisEvent, commit: false)
                added += 1
            } catch {
                continue
            }
        }
        do {
            try store.commit()
        } catch {
            return .failed("The calendar did not save.")
        }
        return .added(added)
    }
}
