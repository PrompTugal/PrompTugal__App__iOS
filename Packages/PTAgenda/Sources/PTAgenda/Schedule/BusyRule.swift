import Foundation
import PTCore

/// Whether a picked session makes the person busy, like a calendar's busy and free (bug 2): being at the venue does
/// not mean being in a room. Only busy against busy is a clash.
public enum ShowsAs: String, Codable, Sendable {
    case busy, free

    public var flipped: ShowsAs { self == .busy ? .free : .busy }
}

public enum BusyRule {
    /// The person's own toggle wins, then the event's `shows_as` from the events JSON when it has one, then the
    /// fallback rule.
    public static func resolve(_ entry: NowModel.Entry, toggled: ShowsAs?, feed: ShowsAs?) -> ShowsAs {
        toggled ?? feed ?? fallback(entry)
    }

    /// Free: registration, opening nights, all-day or multi-hour presence events, venue opening hours.
    /// Busy: talks, panels, workshops, meetings, and anything not recognised.
    public static func fallback(_ entry: NowModel.Entry) -> ShowsAs {
        fallback(kind: entry.kind, title: entry.title, place: entry.place, start: entry.start, end: entry.end)
    }

    public static func fallback(kind: String, title: String, place: String, start: Date, end: Date) -> ShowsAs {
        if freeKinds.contains(kind.lowercased()) { return .free }
        let words = (title + " " + place).lowercased()
        if freePhrases.contains(where: { words.contains($0) }) { return .free }
        if end.timeIntervalSince(start) >= presenceLength { return .free }
        return .busy
    }

    /// Three hours or longer is a place to be, not a room to sit in.
    static let presenceLength: TimeInterval = 3 * 3600
    static let freeKinds: Set<String> = ["registration", "summit", "venue", "presence", "opening"]
    static let freePhrases = ["registration", "opening night", "opening hours", "doors open", "start of the show"]
}

/// What the person decided about their own program, kept on this device only (never sent anywhere, never in the
/// website's schedule document): which picks they marked free or busy, and which clashes they chose to split.
@MainActor @Observable
public final class PlanChoices {
    public static let shared = PlanChoices()

    public private(set) var toggled: [String: ShowsAs]
    public private(set) var splits: Set<String>

    @ObservationIgnored private let defaults: UserDefaults
    private static let toggledKey = "pt.plan.showsAs.v1"
    private static let splitsKey = "pt.plan.splits.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: Self.toggledKey) as? [String: String] ?? [:]
        toggled = raw.compactMapValues(ShowsAs.init(rawValue:))
        splits = Set(defaults.stringArray(forKey: Self.splitsKey) ?? [])
    }

    /// Sets how a pick shows; `nil` goes back to the rule.
    public func set(_ value: ShowsAs?, for id: String) {
        toggled[id] = value
        defaults.set(toggled.mapValues(\.rawValue), forKey: Self.toggledKey)
    }

    public func toggleSplit(_ key: String) {
        if splits.contains(key) { splits.remove(key) } else { splits.insert(key) }
        defaults.set(Array(splits).sorted(), forKey: Self.splitsKey)
    }
}
