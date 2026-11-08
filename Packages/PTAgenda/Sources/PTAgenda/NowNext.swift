import Foundation

/// What the widgets show: sessions happening now and next.
///
/// The app writes it to the App Group container; widgets and intents read it
/// and never touch the vault or the network (brief 05, "Targets").
/// It lives in PTAgenda, which the app and the widget and intents extensions all link.
public struct NowNextSnapshot: Codable, Sendable, Equatable {
    public struct Item: Codable, Sendable, Hashable, Identifiable {
        public var id: String
        public var title: String
        public var place: String
        public var start: Date
        public var end: Date?
        /// True when the person saved or picked it, false for the general agenda.
        public var mine: Bool
        public var url: URL?

        public init(id: String, title: String, place: String, start: Date, end: Date?, mine: Bool, url: URL?) {
            self.id = id
            self.title = title
            self.place = place
            self.start = start
            self.end = end
            self.mine = mine
            self.url = url
        }
    }

    public static let version = 1

    public var version = NowNextSnapshot.version
    public var updatedAt: Date
    /// Sorted by start time. Past items are kept until they end, so "now" works.
    public var items: [Item]

    public init(version: Int = NowNextSnapshot.version, updatedAt: Date, items: [Item]) {
        self.version = version
        self.updatedAt = updatedAt
        self.items = items
    }

    public func now(at date: Date) -> [Item] {
        items.filter { $0.start <= date && date < ($0.end ?? $0.start.addingTimeInterval(30 * 60)) }
    }

    public func next(after date: Date, limit: Int = 3) -> [Item] {
        Array(items.filter { $0.start > date }.prefix(limit))
    }

    /// Times at which `now` or `next` change, for widget timelines.
    public func changes(after date: Date, until limit: Date) -> [Date] {
        let times = items.flatMap { [$0.start, $0.end ?? $0.start.addingTimeInterval(30 * 60)] }
        return Array(Set(times.filter { $0 > date && $0 <= limit })).sorted()
    }
}

public enum SharedContainer {
    /// The App Group the app and its widgets share. The PrompTugal app keeps the original group; an app with its
    /// own group (Team) sets this once at launch, before anything reads or writes the snapshot.
    public nonisolated(unsafe) static var appGroup = "group.news.promptugal.reader"
    public static let nowNextKind = "news.promptugal.reader.now-next"
    private static let nowNextFile = "now-next.json"

    /// The App Group container, or nil when the build has no App Group entitlement
    /// (unsigned CI builds, personal teams).
    public static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    public static func readNowNext() -> NowNextSnapshot? {
        guard let file = url?.appendingPathComponent(nowNextFile),
              let data = try? Data(contentsOf: file) else { return nil }
        return decode(data)
    }

    /// Returns false when there is no App Group container to write to.
    @discardableResult
    public static func writeNowNext(_ snapshot: NowNextSnapshot) throws -> Bool {
        guard let directory = url else { return false }
        try encode(snapshot).write(to: directory.appendingPathComponent(nowNextFile), options: .atomic)
        return true
    }

    public static func encode(_ snapshot: NowNextSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func decode(_ data: Data) -> NowNextSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(NowNextSnapshot.self, from: data),
              snapshot.version == NowNextSnapshot.version else { return nil }
        return snapshot
    }
}

public enum LisbonClock {
    public static let zone = TimeZone(identifier: "Europe/Lisbon")!

    public static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
    }
}
