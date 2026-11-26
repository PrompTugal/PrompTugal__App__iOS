import PTCore
import SwiftUI

/// Everything is connected: the towns at their real positions, joined wherever two towns' AI maps name the same
/// organisation (the Universidade do Algarve, NERA, Algarve Evolution...). Drawn only from the place files.
public struct TownLink: Hashable, Sendable {
    public let a: String
    public let b: String
    /// The shared names, as the first town's file writes them.
    public let shared: [String]
}

public enum PlaceConnections {
    /// Known short forms, so "UAlg" and "Universidade do Algarve" are one organisation.
    static let synonyms: [String: String] = [
        "ualg": "universidade do algarve",
        "university of the algarve": "universidade do algarve",
        "university of algarve": "universidade do algarve",
    ]

    /// Folded text: no case, no accents, words joined by single spaces.
    public static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_PT"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        return synonyms[folded] ?? folded
    }

    /// The names an entity answers to: "Universidade do Algarve (UAlg)" gives "universidade do algarve";
    /// "MARREAL observatory (UAlg, CINTAL, CCMAR)" also gives each bracketed partner; "NERA, Associação..." gives "nera";
    /// "Universidade do Algarve and CCMAR, ..." gives "universidade do algarve".
    public static func keys(_ name: String) -> Set<String> {
        var out = Set<String>()
        var head = name
        if let open = name.firstIndex(of: "("), let close = name[open...].firstIndex(of: ")") {
            head = String(name[..<open])
            for part in name[name.index(after: open)..<close].split(whereSeparator: { $0 == "," || $0 == ";" }) {
                let k = fold(String(part))
                if !k.isEmpty, k.split(separator: " ").count <= 4, !k.contains("research") { out.insert(k) }
            }
        }
        out.insert(fold(head))
        if let comma = head.firstIndex(of: ",") { out.insert(fold(String(head[..<comma]))) }
        if let range = head.range(of: " and ") { out.insert(fold(String(head[..<range.lowerBound]))) }
        return out.filter { $0.count >= 3 }
    }

    /// One key, for display grouping (the first of `keys`, the full head name).
    public static func key(_ name: String) -> String {
        var head = name
        if let open = head.firstIndex(of: "(") { head = String(head[..<open]) }
        return fold(head)
    }

    /// Every pair of places whose AI maps share at least one entity. Pure, so it is tested.
    public static func links(_ files: [PlaceFile]) -> [TownLink] {
        var out: [TownLink] = []
        for (i, a) in files.enumerated() {
            for b in files[(i + 1)...] {
                var shared = Set<String>()
                for x in a.aiMap {
                    let kx = keys(x.name)
                    for y in b.aiMap where !kx.isDisjoint(with: keys(y.name)) {
                        // Name the link by what they share: the common key, written as a title.
                        let common = kx.intersection(keys(y.name)).sorted { $0.count > $1.count }.first ?? key(x.name)
                        shared.insert(display(common, from: [x.name, y.name]))
                    }
                }
                if !shared.isEmpty { out.append(TownLink(a: a.id, b: b.id, shared: shared.sorted())) }
            }
        }
        return out.sorted { $0.shared.count > $1.shared.count }
    }

    /// The original spelling of a key when one of the names starts with it, else the key capitalised.
    static func display(_ key: String, from names: [String]) -> String {
        for name in names {
            let words = name.split(separator: " ")
            for n in stride(from: words.count, through: 1, by: -1) {
                let candidate = words.prefix(n).joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",("))
                if fold(candidate) == key { return candidate }
            }
        }
        return key == "universidade do algarve" ? "Universidade do Algarve" : key.uppercased()
    }

    /// The entities named by more than one place: the hubs of the region.
    public static func hubs(_ files: [PlaceFile]) -> [(name: String, places: [String])] {
        var seen: [String: (name: String, places: [String])] = [:]
        for file in files {
            for entry in file.aiMap {
                for k in keys(entry.name) {
                    var item = seen[k] ?? (display(k, from: [entry.name]), [])
                    if !item.places.contains(file.id) { item.places.append(file.id) }
                    seen[k] = item
                }
            }
        }
        return seen.values.filter { $0.places.count > 1 }.sorted { $0.places.count > $1.places.count }
    }
}

struct ConnectedTownsView: View {
    let store: PlacesStore
    @State private var focus: String?

    private var files: [PlaceFile] { store.algarveTowns.compactMap { store.file($0.id) } }

    var body: some View {
        let links = PlaceConnections.links(files)
        let hubs = PlaceConnections.hubs(files)
        VStack(alignment: .leading, spacing: Space.m) {
            GeometryReader { geo in
                let points = Self.project(store.algarveTowns, in: geo.size)
                ZStack {
                    Canvas { context, _ in
                        for link in links {
                            guard let p = points[link.a], let q = points[link.b] else { continue }
                            let lit = focus == nil || focus == link.a || focus == link.b
                            var path = Path()
                            path.move(to: p)
                            let mid = CGPoint(x: (p.x + q.x) / 2, y: min(p.y, q.y) - 24 - CGFloat(link.shared.count) * 6)
                            path.addQuadCurve(to: q, control: mid)
                            context.stroke(path, with: .color(Palette.red.opacity(lit ? 0.75 : 0.1)),
                                           lineWidth: CGFloat(min(1 + link.shared.count, 6)))
                        }
                    }
                    ForEach(store.algarveTowns) { place in
                        if let p = points[place.id] {
                            let accent = PlaceTheme.accent(store.file(place.id), id: place.id)
                            let degree = links.filter { $0.a == place.id || $0.b == place.id }.count
                            Button {
                                withAnimation(.snappy) { focus = focus == place.id ? nil : place.id }
                            } label: {
                                VStack(spacing: 2) {
                                    Circle().fill(accent)
                                        .frame(width: CGFloat(12 + degree * 3), height: CGFloat(12 + degree * 3))
                                        .overlay(Circle().stroke(.white, lineWidth: focus == place.id ? 3 : 1.5))
                                        .shadow(color: accent.opacity(0.5), radius: 4)
                                    Text(place.name).font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.ink)
                                        .fixedSize()
                                }
                            }
                            .buttonStyle(.plain)
                            .position(p)
                        }
                    }
                }
            }
            .frame(height: 300)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))

            if let focus, let place = store.place(focus) {
                let mine = links.filter { $0.a == focus || $0.b == focus }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(place.name).font(.headline)
                        Spacer()
                        NavigationLink(value: PlaceRoute(focus)) { Text(String(localized: "Open", bundle: .module)).font(.subheadline.weight(.semibold)) }
                    }
                    if mine.isEmpty {
                        Text(String(localized: "No organisation on its AI map is shared with another town yet.", bundle: .module)).font(.caption).foregroundStyle(Palette.muted)
                    }
                    ForEach(mine, id: \.self) { link in
                        let other = store.place(link.a == focus ? link.b : link.a)?.name ?? ""
                        Text("\(other): \(link.shared.joined(separator: ", "))").font(.caption).foregroundStyle(Palette.ink)
                    }
                }
                .padding(Space.m)
                .background(Palette.paper2, in: RoundedRectangle(cornerRadius: 14))
            } else if !hubs.isEmpty {
                WrapLayout(spacing: 6) {
                    ForEach(Array(hubs.prefix(10).enumerated()), id: \.offset) { _, hub in
                        Text("\(hub.name) · \(hub.places.count)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Palette.red.opacity(0.1), in: Capsule())
                            .foregroundStyle(Palette.red)
                    }
                }
            }
        }
        .accessibilityIdentifier("places.connected")
    }

    /// The towns' seats projected into the box (equirectangular, fine at this scale), with a margin.
    static func project(_ places: [PlaceSummary], in size: CGSize) -> [String: CGPoint] {
        let seats = places.compactMap { p in p.at.flatMap { $0.count == 2 ? (p.id, $0[0], $0[1]) : nil } }
        guard let minX = seats.map(\.1).min(), let maxX = seats.map(\.1).max(),
              let minY = seats.map(\.2).min(), let maxY = seats.map(\.2).max() else { return [:] }
        let pad: CGFloat = 36
        let w = max(maxX - minX, 0.01), h = max(maxY - minY, 0.01)
        var out: [String: CGPoint] = [:]
        for (id, lon, lat) in seats {
            let x = pad + CGFloat((lon - minX) / w) * (size.width - 2 * pad)
            let y = pad + 20 + CGFloat((maxY - lat) / h) * (size.height - 2 * pad - 20)
            out[id] = CGPoint(x: x, y: y)
        }
        return out
    }
}
