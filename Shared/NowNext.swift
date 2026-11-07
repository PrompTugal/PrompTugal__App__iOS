import Foundation

/// What the widgets show: sessions happening now and next.
///
/// The app writes it to the App Group container; widgets and intents read it
/// and never touch the vault or the network (brief 05, "Targets").
/// This folder is compiled into the app and every extension.
struct NowNextSnapshot: Codable, Sendable, Equatable {
    struct Item: Codable, Sendable, Hashable, Identifiable {
        var id: String
        var title: String
        var place: String
        var start: Date
        var end: Date?
        /// True when the person saved or picked it, false for the general agenda.
        var mine: Bool
        var url: URL?
    }

    static let version = 1

    var version = NowNextSnapshot.version
    var updatedAt: Date
    /// Sorted by start time. Past items are kept until they end, so "now" works.
    var items: [Item]

    func now(at date: Date) -> [Item] {
        items.filter { $0.start <= date && date < ($0.end ?? $0.start.addingTimeInterval(30 * 60)) }
    }

    func next(after date: Date, limit: Int = 3) -> [Item] {
        Array(items.filter { $0.start > date }.prefix(limit))
    }

    /// Times at which `now` or `next` change, for widget timelines.
    func changes(after date: Date, until limit: Date) -> [Date] {
        let times = items.flatMap { [$0.start, $0.end ?? $0.start.addingTimeInterval(30 * 60)] }
        return Array(Set(times.filter { $0 > date && $0 <= limit })).sorted()
    }
}

enum SharedContainer {
    static let appGroup = "group.news.promptugal.reader"
    static let nowNextKind = "news.promptugal.reader.now-next"
    private static let nowNextFile = "now-next.json"

    /// The App Group container, or nil when the build has no App Group entitlement
    /// (unsigned CI builds, personal teams).
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static func readNowNext() -> NowNextSnapshot? {
        guard let file = url?.appendingPathComponent(nowNextFile),
              let data = try? Data(contentsOf: file) else { return nil }
        return decode(data)
    }

    /// Returns false when there is no App Group container to write to.
    @discardableResult
    static func writeNowNext(_ snapshot: NowNextSnapshot) throws -> Bool {
        guard let directory = url else { return false }
        try encode(snapshot).write(to: directory.appendingPathComponent(nowNextFile), options: .atomic)
        return true
    }

    static func encode(_ snapshot: NowNextSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) -> NowNextSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(NowNextSnapshot.self, from: data),
              snapshot.version == NowNextSnapshot.version else { return nil }
        return snapshot
    }
}

enum LisbonClock {
    static let zone = TimeZone(identifier: "Europe/Lisbon")!

    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
    }
}
