import Foundation
import PTCore
import SwiftUI

// "Since you last looked": https://promptugal.news/api/v1/since.json, everything dated in the last 45 days,
// newest first (our own articles and the local stories the place agents read), each with its source and place.
// Dates are days. The device keeps the newest day it has shown and the items of that day, so what came after is
// marked new. Lenient, like every decoder here: one bad item is dropped, never the feed.

struct SinceFeed: Decodable, Sendable, Equatable {
    var built: String
    var days: Int
    var places: [SincePlace]
    var items: [SinceItem]

    init(built: String = "", days: Int = 45, places: [SincePlace] = [], items: [SinceItem] = []) {
        self.built = built; self.days = days; self.places = places; self.items = items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        built = c.string("built") ?? ""
        days = c.int("days") ?? 45
        places = c.lenientArray("places")
        items = c.lenientArray("items")
    }

    /// Newest first, whatever order the file came in (ties keep the file's order).
    var newestFirst: [SinceItem] {
        items.enumerated().sorted { a, b in
            a.element.date != b.element.date ? a.element.date > b.element.date : a.offset < b.offset
        }.map(\.element)
    }

    /// The place's name: its own place, else the first ring, from the feed's places (the id as written otherwise).
    func placeName(for item: SinceItem) -> String {
        let id = placeID(for: item)
        return places.first { $0.id == id }?.name ?? id.capitalized
    }
}

struct SincePlace: Decodable, Sendable, Equatable {
    var id: String
    var name: String
    var kind: String
    var parent: String

    init(id: String, name: String, kind: String = "", parent: String = "") {
        self.id = id; self.name = name; self.kind = kind; self.parent = parent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = try c.decode(String.self, forKey: AnyKey("id"))
        name = c.string("name") ?? id
        kind = c.string("kind") ?? ""
        parent = c.string("parent") ?? ""
    }
}

struct SinceItem: Decodable, Sendable, Equatable, Hashable, Identifiable {
    /// "article" (PrompTugal.news's own) or "story" (read at a local source).
    var kind: String
    /// "2026-11-24".
    var date: String
    var title: String
    /// The source: the article's page, or the local outlet's story.
    var url: String
    var place: String?
    var rings: [String]
    var publisher: String
    var licenseName: String
    var licenseURL: String
    var readOn: String
    var writtenBy: String

    var id: String { url + "|" + title }
    var isArticle: Bool { kind == "article" }

    init(kind: String = "story", date: String, title: String, url: String, place: String? = nil, rings: [String] = [],
         publisher: String = "") {
        self.kind = kind; self.date = date; self.title = title; self.url = url; self.place = place; self.rings = rings
        self.publisher = publisher; licenseName = ""; licenseURL = ""; readOn = ""; writtenBy = ""
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        title = try c.decode(String.self, forKey: AnyKey("title"))
        let provenance = c.lenient(Origin.self, "provenance")
        let link = c.string("url") ?? provenance?.sourceURL ?? ""
        // Every story links to its source: an item with no link is not shown.
        guard PlaceLinks.web(link) != nil else {
            throw DecodingError.dataCorruptedError(forKey: AnyKey("url"), in: c, debugDescription: "no source link")
        }
        url = link
        kind = c.string("kind") ?? provenance?.kind ?? "story"
        date = c.string("date") ?? provenance?.published ?? ""
        let place = c.string("place")
        self.place = (place?.isEmpty ?? true) ? nil : place
        rings = c.lenientArray("rings")
        publisher = c.string("publisher") ?? provenance?.publisher ?? ""
        let license = c.lenient(License.self, "license")
        licenseName = license?.name ?? ""
        licenseURL = license?.url ?? ""
        readOn = provenance?.readOn ?? ""
        writtenBy = provenance?.writtenBy ?? ""
    }

    /// Who to credit on the row: the outlet for a story, PrompTugal.news for our own articles.
    var byline: String {
        if !publisher.isEmpty { return publisher }
        return isArticle ? "PrompTugal.news" : (URL(string: url)?.host() ?? "")
    }

    private struct Origin: Decodable {
        var sourceURL: String?
        var publisher: String?
        var published: String?
        var readOn: String?
        var writtenBy: String?
        var kind: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            sourceURL = c.string("source_url"); publisher = c.string("publisher"); published = c.string("published")
            readOn = c.string("read_on"); writtenBy = c.string("written_by"); kind = c.string("kind")
        }
    }

    private struct License: Decodable {
        var name: String?
        var url: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            name = c.string("name"); url = c.string("url")
        }
    }
}

/// What this device has already shown from since.json: the newest day, and the items of that day.
struct SinceMarker: Equatable {
    static let key = "places.since.seen"

    var day: String
    var ids: Set<String>
    var at: Date

    /// The marker after showing these items: their newest day, and every item of that day.
    init(showing items: [SinceItem], at: Date = .now) {
        let newest = items.map(\.date).max() ?? ""
        day = newest
        ids = Set(items.filter { $0.date == newest }.map(\.id))
        self.at = at
    }

    init(day: String, ids: Set<String>, at: Date) { self.day = day; self.ids = ids; self.at = at }

    func isNew(_ item: SinceItem) -> Bool {
        item.date > day || (item.date == day && !ids.contains(item.id))
    }

    // Kept as a small JSON string in UserDefaults.
    var raw: String {
        let object: [String: Any] = ["day": day, "ids": ids.sorted(), "at": at.timeIntervalSince1970]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    init?(raw: String) {
        guard let data = raw.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let day = object["day"] as? String, !day.isEmpty else { return nil }
        self.day = day
        ids = Set(object["ids"] as? [String] ?? [])
        at = Date(timeIntervalSince1970: object["at"] as? Double ?? 0)
    }

    static func load(_ defaults: UserDefaults = .standard) -> SinceMarker? {
        defaults.string(forKey: key).flatMap { SinceMarker(raw: $0) }
    }

    func save(_ defaults: UserDefaults = .standard) { defaults.set(raw, forKey: Self.key) }
}

// MARK: - The section on the places home

/// The newest from since.json, each opening its source, with its place, and what came after the reader's last look
/// marked "New". The marker read at launch stays for the whole session, so the marks do not vanish on a scroll; the
/// newest seen is saved as soon as the items show, for next time.
struct SinceYouLookedSection: View {
    let store: PlacesStore
    let wide: Bool
    @State private var showAll = false

    /// The marker as it was at launch, read once and kept for the session.
    @MainActor private static var session: SinceMarker?
    @MainActor private static var sessionRead = false

    @MainActor static func sessionBaseline() -> SinceMarker? {
        if !sessionRead {
            session = SinceMarker.load()
            sessionRead = true
        }
        return session
    }

    private var feed: SinceFeed? { store.since.value }

    private static func newestDate(_ items: [SinceItem]) -> String? { items.map(\.date).max() }

    var body: some View {
        if let feed, !feed.items.isEmpty {
            content(feed)
                .task(id: feed.items.first?.id) { SinceMarker(showing: feed.items).save() }
        }
    }

    private func content(_ feed: SinceFeed) -> some View {
        let baseline = Self.sessionBaseline()
        let all = feed.newestFirst
        let fresh = baseline.map { b in all.filter { b.isNew($0) } } ?? []
        let limit = wide ? 12 : 8
        let shown: [SinceItem] = fresh.isEmpty ? all : fresh
        let pool: [SinceItem] = showAll ? shown : Array(shown.prefix(limit))
        return VStack(alignment: .leading, spacing: Space.m) {
            SectionHead(title: String(localized: "Since you last looked", bundle: .module),
                        subtitle: subtitle(baseline: baseline, fresh: fresh.count, days: feed.days), accent: Palette.red)
            PlacesOriginLabel(origin: store.since.origin(dataDate: Self.newestDate(feed.items), story: true))
            VStack(spacing: 0) {
                ForEach(pool) { item in
                    SinceRow(item: item, place: feed.placeName(for: item), isNew: baseline?.isNew(item) ?? false,
                             accent: accent(for: item))
                    Divider()
                }
            }
            moreButton(total: shown.count, limit: limit)
        }
        .padding(.horizontal, wide ? Space.xxl : Space.l)
        .accessibilityIdentifier("places.since")
    }

    private func accent(for item: SinceItem) -> Color {
        let id = item.place ?? item.rings.first ?? "portugal"
        return PlaceTheme.accent(store.file(id), id: id)
    }

    @ViewBuilder private func moreButton(total: Int, limit: Int) -> some View {
        if total > limit {
            Button {
                withAnimation(.snappy) { showAll.toggle() }
            } label: {
                Text(showAll ? String(localized: "Show fewer", bundle: .module) : String(localized: "Show all \(total)", bundle: .module))
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Palette.red)
        }
    }

    private func subtitle(baseline: SinceMarker?, fresh: Int, days: Int) -> String {
        guard let baseline else {
            return String(localized: "Your first look: the newest from the last \(days) days, each with its source", bundle: .module)
        }
        let when = PlacesOrigin.day(baseline.at)
        if fresh == 0 { return String(localized: "Nothing new since \(when). The newest, each with its source:", bundle: .module) }
        return fresh == 1 ? String(localized: "1 new since \(when)", bundle: .module) : String(localized: "\(fresh) new since \(when)", bundle: .module)
    }
}

/// One item: kind, place, outlet and day, a "New" mark, the title; a tap opens the source.
struct SinceRow: View {
    let item: SinceItem
    let place: String
    let isNew: Bool
    let accent: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        StoryOpen(link: item.url) {
            HStack(alignment: .top, spacing: Space.m) {
                Rectangle().fill(accent).frame(width: 4)
                VStack(alignment: .leading, spacing: 4) {
                    meta
                    Text(item.title)
                        .font(Typo.story)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    source
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("places.since.item")
    }

    private var meta: some View {
        HStack(spacing: 6) {
            if isNew {
                Text(String(localized: "New", bundle: .module))
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Palette.red, in: Capsule())
                    .foregroundStyle(.white)
            }
            Text(place)
                .font(.caption2.weight(.heavy)).textCase(.uppercase)
                .foregroundStyle(accent)
            Text(item.isArticle ? String(localized: "Our article", bundle: .module) : String(localized: "Story", bundle: .module))
                .font(.caption2).foregroundStyle(Palette.muted)
            Spacer(minLength: 0)
            Text(PlaceDates.age(item.date)).font(.caption2).foregroundStyle(Palette.muted)
        }
    }

    private var source: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.right.square")
            Text(String(localized: "Read at \(item.byline)", bundle: .module))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(accent)
        .lineLimit(1)
    }
}
