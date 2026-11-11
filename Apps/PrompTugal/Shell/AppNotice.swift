import PTAgenda
import PTCore
import PTNews
import PTWeb
import SwiftUI

/// A short notice at the top of Now (the storm of 11 November first), read from promptugal.news so the correspondent
/// can change it without an app release: assets/live/app-notice.json. Shown only between `show_from` and `show_until`.
/// Plain text only; the link must be https on promptugal.news. The last copy is kept for offline.
struct AppNotice: Decodable, Equatable {
    struct Link: Decodable, Equatable {
        let title: String
        let url: URL
    }

    let id: String
    let showFrom: Date
    let showUntil: Date
    let kicker: String?
    let title: String
    let lines: [String]
    let link: Link?
    let sources: String?
    /// Summit days called off (Lisbon dates). Applies whether or not the card is still showing.
    let cancelledDays: [String]?

    enum CodingKeys: String, CodingKey {
        case id, kicker, title, lines, link, sources
        case cancelledDays = "cancelled_days"
        case showFrom = "show_from"
        case showUntil = "show_until"
    }

    static let url = FeedClient.site.appendingPathComponent("assets/live/app-notice.json")

    static func decode(_ data: Data) throws -> AppNotice {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppNotice.self, from: data)
    }

    func isShowing(at date: Date) -> Bool { date >= showFrom && date < showUntil }

    /// The link, only when it stays on promptugal.news over https.
    var safeLink: Link? {
        guard let link, link.url.scheme == "https", link.url.host() == FeedClient.site.host() else { return nil }
        return link
    }
}

@MainActor @Observable
final class AppNoticeStore {
    static let shared = AppNoticeStore()

    private(set) var notice: AppNotice?
    private var lastLoad: Date?
    private var saved: URL { URL.cachesDirectory.appending(path: "app-notice.json") }

    init() {
        notice = (try? Data(contentsOf: saved)).flatMap { try? AppNotice.decode($0) }
        AgendaHub.cancelledDays = Set(notice?.cancelledDays ?? [])
    }

    /// Called at launch, before the first screen, so a day called off never shows even offline.
    static func start() { _ = shared }

    /// At most every five minutes, unless forced (pull to refresh).
    func load(force: Bool = false) async {
        if !force, let lastLoad, Date.now.timeIntervalSince(lastLoad) < 300 { return }
        lastLoad = .now
        guard let (data, response) = try? await URLSession.shared.data(from: AppNotice.url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let fresh = try? AppNotice.decode(data) else { return }
        notice = fresh
        try? data.write(to: saved, options: .atomic)
        let cancelled = Set(fresh.cancelledDays ?? [])
        if cancelled != AgendaHub.cancelledDays {
            AgendaHub.cancelledDays = cancelled
            _ = await PublicFeatures.shared.reminders.reschedule()
        }
    }
}

/// The card: kicker, title, the lines, the sources, and the article.
struct AppNoticeCard: View {
    let now: Date
    @State private var store = AppNoticeStore.shared

    var body: some View {
        Group {
            if let notice = store.notice, notice.isShowing(at: now) {
                Card {
                    if let kicker = notice.kicker { Kicker(kicker, color: Palette.amber) }
                    Text(notice.title).font(Typo.headline).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(notice.lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.subheadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    if let sources = notice.sources {
                        Text(sources).font(.footnote).foregroundStyle(Palette.muted)
                    }
                    if let link = notice.safeLink {
                        NavigationLink { SitePage(url: link.url, title: link.title) } label: {
                            Label(link.title, systemImage: "arrow.forward.circle")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .accessibilityIdentifier("pt.now.notice")
            }
        }
        .task { await store.load() }
    }
}
