import Foundation
import WidgetKit

/// Writes the "Now and next" snapshot to the App Group for the widgets, and
/// asks WidgetKit to reload them when it changes.
///
/// Today the source is the reader's agenda and saved sessions. When the
/// schedule store lands, its picks should be passed as `saved`.
@MainActor
enum NowNextPublisher {
    private static var lastWritten: NowNextSnapshot?

    static func publish(agenda: [Event], saved: [Event], now: Date = .now) {
        let snapshot = makeSnapshot(agenda: agenda, saved: saved, now: now)
        guard snapshot.items != lastWritten?.items else { return }
        do {
            guard try SharedContainer.writeNowNext(snapshot) else { return }
            lastWritten = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: SharedContainer.nowNextKind)
        } catch {
            // Widgets keep their last timeline; nothing for the person to do.
        }
    }

    /// Saved sessions that have not ended, plus agenda sessions running now or
    /// starting within `horizon`, up to `limit`, sorted by start.
    nonisolated static func makeSnapshot(agenda: [Event], saved: [Event], now: Date,
                                         horizon: TimeInterval = 36 * 3_600, limit: Int = 40) -> NowNextSnapshot {
        let savedIDs = Set(saved.map(\.id))
        func item(_ event: Event) -> NowNextSnapshot.Item? {
            guard let start = event.start else { return nil }
            let end = event.end ?? start.addingTimeInterval(30 * 60)
            guard end > now else { return nil }
            return .init(id: event.id, title: event.title, place: event.place, start: start, end: event.end,
                         mine: savedIDs.contains(event.id), url: event.url)
        }
        let mine = saved.compactMap(item)
        let others = agenda.filter { !savedIDs.contains($0.id) }.compactMap(item)
            .filter { $0.start <= now.addingTimeInterval(horizon) }
        let items = (mine + others).sorted { ($0.start, $0.title) < ($1.start, $1.title) }
        return NowNextSnapshot(updatedAt: now, items: Array(items.prefix(limit)))
    }
}
