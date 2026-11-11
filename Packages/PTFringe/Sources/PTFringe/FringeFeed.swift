import Foundation

/// Reads the events file in any of the shapes the site or the seed may use: `{"events": [...]}`, `{"items": [...]}`
/// or a bare array. One malformed event is skipped; the rest are kept.
public enum FringeFeed {
    private struct Lenient: Decodable {
        let event: FringeEvent?
        init(from decoder: Decoder) throws { event = try? FringeEvent(from: decoder) }
    }
    private struct Wrapped: Decodable {
        let events: [Lenient]?
        let items: [Lenient]?
    }

    public static func events(from data: Data) throws -> [FringeEvent] {
        let decoder = JSONDecoder()
        let lenient: [Lenient]
        if let wrapped = try? decoder.decode(Wrapped.self, from: data), let list = wrapped.events ?? wrapped.items {
            lenient = list
        } else {
            lenient = try decoder.decode([Lenient].self, from: data)
        }
        return lenient.compactMap(\.event).sorted(by: FringeEvent.earlier)
    }
}

extension FringeEvent {
    /// Day, then start (events with no start after those with one), then name.
    public static func earlier(_ lhs: FringeEvent, _ rhs: FringeEvent) -> Bool {
        // An event with no date sorts after every dated one.
        let (a, b) = (lhs.date.isEmpty ? "9999" : lhs.date, rhs.date.isEmpty ? "9999" : rhs.date)
        if a != b { return a < b }
        switch (lhs.start, rhs.start) {
        case let (a?, b?) where a != b: return a < b
        case (nil, .some): return false
        case (.some, nil): return true
        default: return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
