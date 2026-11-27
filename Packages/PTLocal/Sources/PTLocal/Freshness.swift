import Foundation

/// How fresh a feed is, judged by the feed's own read time (`read_at`, `generatedAt`, `at`, `updated`), not by when
/// this device fetched it. A file fetched a second ago can still hold data read days ago: then it is a snapshot, and
/// the screen says so. Pure, so it is tested without a view.
public enum Freshness: Equatable, Sendable {
    /// Read by the feed within the live window (3 hours).
    case live(Date)
    /// Read by the feed longer ago than the live window.
    case snapshot(Date)
    /// The feed gives no read time we can parse.
    case unknown

    /// Under this age a feed's data counts as live.
    public static let liveWindow: TimeInterval = 3 * 3600

    /// From a read time. A time ahead of the clock (agents write those) counts as now.
    public static func of(_ read: Date?, now: Date = Date(), window: TimeInterval = liveWindow) -> Freshness {
        guard let read else { return .unknown }
        let clamped = min(read, now)
        return now.timeIntervalSince(clamped) < window ? .live(clamped) : .snapshot(clamped)
    }

    /// The newest of several read stamps ("2026-11-21T09:20:40Z", "2026-11-21", ...); unreadable ones are skipped.
    public static func newest(_ stamps: [String?]) -> Date? {
        stamps.compactMap { NewsroomDate.parse($0) }.max()
    }

    public var isLive: Bool { if case .live = self { true } else { false } }

    public var readAt: Date? {
        switch self {
        case .live(let date), .snapshot(let date): date
        case .unknown: nil
        }
    }

    /// "Live, read 22:10", "Snapshot, read 21 Nov" (with the year when it is not this year), or "Read time not given".
    public func label(now: Date = Date(), timeZone: TimeZone = .current) -> String {
        switch self {
        case .live(let date): LocalText.string("Live, read \(String(describing: Self.time(date, timeZone: timeZone)))")
        case .snapshot(let date): LocalText.string("Snapshot, read \(String(describing: Self.day(date, now: now, timeZone: timeZone)))")
        case .unknown: LocalText.string("Read time not given")
        }
    }

    static func time(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalText.locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func day(_ date: Date, now: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = LocalText.locale
        formatter.timeZone = timeZone
        formatter.dateFormat = sameYear ? "d MMM" : "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// The one line a screen shows: how it got the data (fetched, this device's copy, built in) and how fresh the data
    /// itself is. Fetched now but read by the feed days ago reads "Snapshot, read 21 Nov, from data.promptugal.news".
    public static func line(provenance: Provenance, readAt: Date?, host: String = "promptugal.news",
                            now: Date = Date(), timeZone: TimeZone = .current) -> (text: String, isLive: Bool) {
        guard let readAt else { return (provenance.label, provenance.isLive) }
        let freshness = Freshness.of(readAt, now: now)
        let label = freshness.label(now: now, timeZone: timeZone)
        switch provenance {
        case .live:
            return (LocalText.string("\(String(describing: label)), from \(String(describing: host))"), freshness.isLive)
        case .cached:
            return (LocalText.string("Offline: this device's copy. \(String(describing: label))"), false)
        case .snapshot:
            return (LocalText.string("Built-in copy. \(String(describing: label))"), false)
        case .none:
            return (provenance.label, false)
        }
    }
}
