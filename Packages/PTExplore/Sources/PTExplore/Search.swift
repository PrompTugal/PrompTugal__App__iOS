import Foundation

/// Search over the index. Case and accents do not matter ("sao" finds "São"); every word must match.
public enum ExploreSearch {
    public static func normalise(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en"))
    }

    /// Entries of `kind` (all kinds when nil) that match `query`, best first. An empty query returns every
    /// entry of the kind: talks by time, everything else by title.
    public static func search(_ index: ExploreIndex, query: String, kind: ExploreKind? = nil) -> [ExploreItem] {
        let words = normalise(query).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let pool = index.items.filter { kind == nil || $0.kind == kind }
        if words.isEmpty { return pool.sorted(by: ordered) }
        let scored: [(ExploreItem, Int)] = pool.compactMap { item in
            let title = normalise(item.title)
            let subtitle = normalise(item.subtitle)
            let rest = normalise(item.text)
            var total = 0
            for word in words {
                if title.hasPrefix(word) { total += 100 }
                else if title.split(separator: " ").contains(where: { $0.hasPrefix(word) }) { total += 80 }
                else if title.contains(word) { total += 50 }
                else if subtitle.contains(word) { total += 30 }
                else if rest.contains(word) { total += 10 }
                else { return nil }
            }
            return (item, total)
        }
        return scored.sorted { a, b in
            a.1 != b.1 ? a.1 > b.1 : ordered(a.0, b.0)
        }.map(\.0)
    }

    /// Talks by day and time, everything else by title.
    static func ordered(_ a: ExploreItem, _ b: ExploreItem) -> Bool {
        switch (a.day, b.day) {
        case let (da?, db?) where da != db: return da < db
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        if let sa = a.start, let sb = b.start, sa != sb { return paddedTime(sa) < paddedTime(sb) }
        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
    }

    private static func paddedTime(_ t: String) -> String { t.count == 4 ? "0" + t : t }

    /// How many entries of each kind match, for the kind picker.
    public static func counts(_ index: ExploreIndex, query: String) -> [ExploreKind: Int] {
        var result: [ExploreKind: Int] = [:]
        for kind in ExploreKind.allCases { result[kind] = search(index, query: query, kind: kind).count }
        return result
    }
}
