import Foundation

/// The `-PTSeedPicks <ids>` launch argument for App Store screenshots and tests: a comma-separated list of picks, each
/// either a bare slug or the full pick id (`events/<slug>/index.html`). The app calls this in DEBUG builds only.
public enum PickSeed {
    public static let argument = "-PTSeedPicks"

    /// The schedule ids (slugs) named after `-PTSeedPicks` in `arguments`; empty when the argument is absent.
    public static func ids(in arguments: [String]) -> [String] {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return [] }
        var seen = Set<String>()
        return arguments[index + 1].split(separator: ",").compactMap { item -> String? in
            let text = item.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = ScheduleID.fromPage(text) ?? text
            return ScheduleID.isValid(id) && seen.insert(id).inserted ? id : nil
        }
    }
}

extension ScheduleStore {
    /// Picks each id that is not picked yet. Ids the agenda knows get their event copy on the next `updateEvents`.
    public func seedPicks(_ ids: [String]) {
        for id in ids where !isPicked(id) { toggle(id) }
    }

    /// Seeds from the process arguments (`-PTSeedPicks`). Call from DEBUG code only.
    public func seedPicks(arguments: [String] = ProcessInfo.processInfo.arguments) {
        seedPicks(PickSeed.ids(in: arguments))
    }
}
