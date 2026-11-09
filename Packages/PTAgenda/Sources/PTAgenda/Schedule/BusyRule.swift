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

    /// The shared rule (PrompTugal__App__Mobile `formats/schedule-rules`, so iOS, Android and the web agree): free when
    /// the lowercased title contains one of `freeTitlePatterns`, or the session lasts `freeMinimumMinutes` or more
    /// (all-day and multi-hour presence events); busy otherwise: talks, panels, workshops, meetings.
    public static func fallback(_ entry: NowModel.Entry) -> ShowsAs {
        fallback(title: entry.title, start: entry.start, end: entry.end)
    }

    public static func fallback(title: String, start: Date, end: Date) -> ShowsAs {
        let lower = title.lowercased()
        if freeTitlePatterns.contains(where: { lower.contains($0) }) { return .free }
        return end.timeIntervalSince(start) >= TimeInterval(freeMinimumMinutes * 60) ? .free : .busy
    }

    static let freeMinimumMinutes = 180
    static let freeTitlePatterns = ["registration", "badge pick", "opening night", "opening party", "start of the show",
                                    "start-of-the-show", "doors open", "venue open", "venue hours", "all day", "all-day"]
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
