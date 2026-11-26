import Foundation

/// The sections Dinis asked for (15 Nov, ~23:45, via conductor.a.ios@), from the AI map's `type`: government,
/// companies, startups, investors, universities and research, not-for-profits and communities, talent. A type the
/// place agents add later lands in "Other" until it gets its own section.
public enum PlaceKind: String, CaseIterable, Identifiable, Sendable {
    case government, companies, startups, investors, research, community, talent, other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .government: String(localized: "Government", bundle: .module)
        case .companies: String(localized: "Companies", bundle: .module)
        case .startups: String(localized: "Startups", bundle: .module)
        case .investors: String(localized: "Investors", bundle: .module)
        case .research: String(localized: "Universities and research", bundle: .module)
        case .community: String(localized: "Not-for-profits and communities", bundle: .module)
        case .talent: String(localized: "Talent", bundle: .module)
        case .other: String(localized: "Other", bundle: .module)
        }
    }

    public var symbol: String {
        switch self {
        case .government: "building.columns.fill"
        case .companies: "building.2.fill"
        case .startups: "sparkles"
        case .investors: "eurosign.circle.fill"
        case .research: "graduationcap.fill"
        case .community: "person.3.fill"
        case .talent: "person.crop.circle.badge.checkmark"
        case .other: "circle.hexagongrid.fill"
        }
    }

    public static func of(_ type: String) -> PlaceKind {
        let t = type.lowercased()
        if t.contains("public") || t.contains("council") || t.contains("government") || t.contains("câmara") || t.contains("municipal") { return .government }
        if t.contains("startup") { return .startups }
        if t.contains("investor") || t.contains("fund") || t.contains("investment") { return .investors }
        if t.contains("institution") || t.contains("university") || t.contains("research") || t.contains("school") { return .research }
        if t.contains("organisation") || t.contains("organization") || t.contains("community") || t.contains("association")
            || t.contains("cooperative") || t.contains("non-profit") || t.contains("not-for-profit") { return .community }
        if t.contains("person") || t.contains("talent") || t.contains("people") { return .talent }
        if t.contains("company") || t.contains("business") || t.contains("firm") { return .companies }
        return .other
    }

    /// The kinds present in a map, in this enum's order, with their entries.
    public static func groups(_ entries: [MapEntry]) -> [(kind: PlaceKind, entries: [MapEntry])] {
        let grouped = Dictionary(grouping: entries) { of($0.type) }
        return allCases.compactMap { kind in grouped[kind].map { (kind, $0) } }
    }
}
