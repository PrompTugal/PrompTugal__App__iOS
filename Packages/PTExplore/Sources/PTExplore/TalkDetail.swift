import PTCore
import SwiftUI

/// A talk, named by what the caller has. It is enough to show the talk at once, offline; the full record
/// (speakers, track) is read from cache or the site when the screen opens.
public struct TalkRef: Hashable, Sendable {
    /// The talk's slug: `events/<slug>/index.html` on the site.
    public var slug: String
    public var title: String?
    /// Lisbon day `2026-11-10`, and `12:00`, `12:45`.
    public var day: String?
    public var start: String?
    public var end: String?
    public var place: String?
    public var kind: String?
    public var page: URL?

    public init(slug: String, title: String? = nil, day: String? = nil, start: String? = nil, end: String? = nil,
                place: String? = nil, kind: String? = nil, page: URL? = nil) {
        self.slug = slug
        self.title = title
        self.day = day
        self.start = start
        self.end = end
        self.place = place
        self.kind = kind
        self.page = page
    }

    /// From any id form: a pick id or an `Event.id` (`events/<slug>/index.html`), a reference (`event:<slug>`),
    /// or the bare slug.
    public init(id: String) {
        var slug = id
        if slug.hasPrefix("event:") { slug.removeFirst("event:".count) }
        let parts = slug.split(separator: "/")
        if parts.count == 3, parts[0] == "events" { slug = String(parts[1]) }
        self.init(slug: slug)
    }

    /// From the agenda's event (PTCore).
    public init(_ event: Event) {
        var ref = TalkRef(id: event.page)
        ref.title = event.title
        ref.day = event.date
        let times = event.time.split(separator: "-").map(String.init)
        ref.start = times.first
        ref.end = times.count > 1 ? times[1] : nil
        ref.place = event.place
        ref.kind = event.kind
        ref.page = event.url
        self = ref
    }

    public init(_ item: ExploreItem) {
        self.init(slug: item.slug, title: item.title, day: item.day, start: item.start, end: item.end,
                  place: item.subtitle.isEmpty ? nil : item.subtitle, kind: item.text.isEmpty ? nil : item.text, page: item.page)
    }

    public var reference: String { "event:\(slug)" }

    var item: ExploreItem {
        ExploreItem(id: reference, kind: .event, title: title ?? slug, subtitle: place ?? "", text: kind ?? "",
                    day: day, start: start, end: end, page: page)
    }

    var timeText: String? {
        guard let start else { return nil }
        return end.map { "\(start)–\($0)" } ?? start
    }
}

/// Views the app plugs into the talk detail, because the pick and the calendar live in PTAgenda.
public struct TalkActions {
    /// The pick control, e.g. a large "Add to My program" button for the talk.
    public var pick: (@MainActor (TalkRef) -> AnyView)?
    /// The calendar control, "Add to Calendar".
    public var calendar: (@MainActor (TalkRef) -> AnyView)?

    public init(pick: (@MainActor (TalkRef) -> AnyView)? = nil, calendar: (@MainActor (TalkRef) -> AnyView)? = nil) {
        self.pick = pick
        self.calendar = calendar
    }
}

/// The one native talk detail of the public app (EXP-D). Open it from the agenda, My program, Explore or a
/// widget link:
///
///     TalkDetailView(talk: TalkRef(event), actions: TalkActions(pick: …, calendar: …))
///     TalkDetailView(talk: TalkRef(id: pick.id), actions: …)
///
/// It shows what the caller passed at once, then adds the speakers and place from the talk's record, which it
/// reads from the disk cache when offline.
public struct TalkDetailView: View {
    let talk: TalkRef
    let actions: TalkActions
    @State private var store: ExploreStore
    @State private var detail: ExploreDetail?
    @State private var failed = false

    public init(talk: TalkRef, store: ExploreStore? = nil, actions: TalkActions = TalkActions()) {
        self.talk = talk
        self.actions = actions
        _store = State(initialValue: store ?? ExploreStore())
    }

    private var title: String { talk.title ?? detail?.title ?? talk.slug }
    private var place: String? { talk.place ?? detail?.facts.first { $0.label == ExploreDetail.placeLabel }?.value }

    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.xs) {
                    if let kind = talk.kind ?? detail?.facts.first(where: { $0.label == ExploreDetail.kindLabel })?.value {
                        Text(ExploreFormat.kindTitle(kind)).font(Typo.kicker).foregroundStyle(Palette.red)
                    }
                    Text(title).font(Typo.title)
                    if let day = talk.day {
                        Text([ExploreFormat.day(day), talk.timeText].compactMap { $0 }.joined(separator: " · "))
                            .font(Typo.data).foregroundStyle(Palette.muted)
                    }
                    if let place { Text(place).font(Typo.body).foregroundStyle(Palette.muted) }
                }
            }
            if actions.pick != nil || actions.calendar != nil {
                Section {
                    if let pick = actions.pick { pick(talk) }
                    if let calendar = actions.calendar { calendar(talk) }
                }
            }
            if let detail {
                if !detail.speakers.isEmpty {
                    Section(String(localized: "Speakers", bundle: .module)) {
                        ForEach(detail.speakers) { link in
                            if let person = store.index?.item(ref: link.ref) {
                                NavigationLink { ExploreDetailView(item: person, store: store) } label: { Text(link.label) }
                            } else {
                                Text(link.label)
                            }
                        }
                    }
                }
            } else if failed {
                Section {
                    Text(String(localized: "Connect to see speakers", bundle: .module)).foregroundStyle(Palette.muted)
                }
            } else {
                Section { ProgressView() }
            }
            if let page = talk.page ?? detail?.pageURL {
                Section {
                    Link(destination: page) {
                        Label(String(localized: "Open on promptugal.news", bundle: .module), systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: talk.slug) {
            failed = false
            do { detail = try await store.source.detail(for: talk.item) } catch is CancellationError {} catch { failed = true }
            if store.index == nil { await store.load() }
        }
    }
}
