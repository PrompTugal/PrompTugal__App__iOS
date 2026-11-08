import PTAgenda
import PTAsk
import PTCore
import PTNews
import PTWeb
import SwiftUI

/// Opens a screen of the app by id (a tab, or Settings). The shell sets it; a card on a screen calls it.
private struct OpenDestinationKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var openDestination: (String) -> Void {
        get { self[OpenDestinationKey.self] }
        set { self[OpenDestinationKey.self] = newValue }
    }
}

/// Now (ux spec NOW-1): the first screen. It changes with the summit's phase, worked out from Lisbon time and the
/// agenda (`NowBoard`, PTAgenda): before the summit a countdown, during it For you, On now and Up next, between days
/// Tomorrow, after it a thank you. The latest news, the practical card and the Ask card are in every phase.
/// Every user-facing string is written exactly as in the ux spec, so the String Catalog keys match.
struct NowView: View {
    @Environment(ReaderStore.self) private var reader

    var body: some View {
        // One minute at a time: the clock, the board and the countdowns follow it. `-PTNow` fixes the time in DEBUG builds.
        TimelineView(.everyMinute) { context in
            let now = PublicLaunch.now ?? context.date
            let board = reader.nowBoard(at: now)
            Page(maxWidth: Space.readable) {
                header(now: now)
                switch board.phase {
                case .noAgenda:
                    agendaMissing
                case .before(let start):
                    countdown(to: start, from: now)
                    startProgram(board: board, now: now)
                case .live:
                    forYou(board: board, now: now)
                    onNow(board: board, now: now)
                    upNext(board: board, now: now)
                case .between(let next):
                    forYou(board: board, now: now)
                    tomorrow(after: next, now: now)
                case .ended:
                    thanks
                }
                LatestNewsCard()
                PracticalCard()
                AskCard()
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle("Now")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reader.refresh() }
    }

    // MARK: Header: the date and the time in Lisbon, then how fresh the data is

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Kicker("Lisbon · " + now.formatted(Self.dayStyle))
            Text(Lisbon.timeLabel(now))
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .accessibilityLabel("Time in Lisbon, " + Lisbon.timeLabel(now))
            FreshnessLabel(updated: reader.agendaUpdated ?? reader.newsUpdated,
                           failed: reader.agendaUnavailable || reader.newsUnavailable)
        }
    }

    private static let dayStyle: Date.FormatStyle = {
        var style = Date.FormatStyle().weekday(.wide).day().month(.wide)
        style.timeZone = Lisbon.zone
        return style
    }()

    /// No agenda yet: nothing to count down to or to list, so the screen says so instead of showing empty cards.
    private var agendaMissing: some View {
        TitledCard(String(localized: "Agenda")) {
            Text(reader.agendaUnavailable
                 ? LocalizedStringKey("The agenda could not be loaded. Pull down to try again.")
                 : LocalizedStringKey("Loading the agenda…"))
                .font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    // MARK: State A, before the summit

    /// The first two official items: registration and Opening Night (the first two sessions when they are not in the agenda).
    private var firstItems: [Event] {
        let timed = reader.agenda.filter { $0.start != nil }
            .sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
        let registration = timed.first { $0.title.localizedCaseInsensitiveContains("registration") }
        let opening = timed.first { $0.title.localizedCaseInsensitiveContains("opening night") }
        let named = [registration, opening].compactMap { $0 }
        return named.isEmpty ? Array(timed.prefix(2)) : named
    }

    private func countdown(to start: Date, from now: Date) -> some View {
        TitledCard(Self.countdownTitle(to: start, from: now), kicker: "Lisbon · 9–12 Nov") {
            VStack(alignment: .leading, spacing: Space.m) {
                ForEach(firstItems, id: \.id) { event in
                    EventLink(event: event) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                            Text(Self.whenAndWhere(event)).font(Typo.data).foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
        }
    }

    /// "The summit starts in 1 day" (or 5 hours, 20 minutes): the whole unit that fits.
    static func countdownTitle(to start: Date, from now: Date) -> String {
        let minutes = max(0, Int(start.timeIntervalSince(now) / 60))
        switch minutes {
        case 2 * 1440...: let days = minutes / 1440; return String(localized: "The summit starts in \(days) days")
        case 1440...: return String(localized: "The summit starts in 1 day")
        case 120...: let hours = minutes / 60; return String(localized: "The summit starts in \(hours) hours")
        case 60...: return String(localized: "The summit starts in 1 hour")
        default:
            let count = max(1, minutes)
            return count == 1 ? String(localized: "The summit starts in 1 minute")
                : String(localized: "The summit starts in \(count) minutes")
        }
    }

    private static func whenAndWhere(_ event: Event) -> String {
        guard let start = event.start else { return event.place }
        let day = start.formatted(Self.shortDayStyle)
        return [day + ", " + Lisbon.timeLabel(start), event.place].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static let shortDayStyle: Date.FormatStyle = {
        var style = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        style.timeZone = Lisbon.zone
        return style
    }()

    /// NOW-1b: with no picks, a card that starts the program; with picks, the next one.
    @ViewBuilder private func startProgram(board: NowBoard.Snapshot, now: Date) -> some View {
        if reader.saved.isEmpty {
            StartProgramCard()
        } else {
            forYou(board: board, now: now)
        }
    }

    // MARK: State B, during the summit

    /// Registration is not a talk: it never fills On now or Up next.
    private static func isRegistration(_ entry: NowBoard.Entry) -> Bool {
        entry.title.localizedCaseInsensitiveContains("registration")
    }

    /// NOW-1c: my current pick, or my next one.
    @ViewBuilder private func forYou(board: NowBoard.Snapshot, now: Date) -> some View {
        if let entry = board.mineNow.first ?? board.nextMine {
            let clash = board.clashes.contains { $0.first.eventID == entry.id || $0.second.eventID == entry.id }
            TitledCard(String(localized: "For you"),
                       kicker: board.mineNow.first != nil ? String(localized: "On now") : String(localized: "Next in your program")) {
                SessionRow(entry: entry, now: now, style: .forYou, clash: clash)
            }
        } else if board.phase == .live {
            StartProgramCard()
        }
    }

    /// NOW-1f: up to five sessions running now, Centre Stage first.
    @ViewBuilder private func onNow(board: NowBoard.Snapshot, now: Date) -> some View {
        let running = board.venueNow.filter { !Self.isRegistration($0) }.sorted { lhs, rhs in
            let l = Self.isCentreStage(lhs.place), r = Self.isCentreStage(rhs.place)
            if l != r { return l }
            return lhs.start < rhs.start
        }
        if !running.isEmpty {
            TitledCard(String(localized: "On now at the venue"), accessory: {
                if running.count > 5 {
                    SeeAllButton(title: String(localized: "See all (\(running.count))"))
                }
            }, content: {
                ForEach(running.prefix(5)) { entry in
                    SessionRow(entry: entry, now: now, style: .onNow, clash: false)
                }
            })
        }
    }

    private static func isCentreStage(_ place: String) -> Bool {
        place.localizedCaseInsensitiveContains("centre stage") || place.localizedCaseInsensitiveContains("center stage")
    }

    /// NOW-1g: up to five sessions starting in the next 60 minutes.
    @ViewBuilder private func upNext(board: NowBoard.Snapshot, now: Date) -> some View {
        let soon = board.venueNext.filter { $0.start <= now.addingTimeInterval(3600) && !Self.isRegistration($0) }
        if !soon.isEmpty {
            TitledCard(String(localized: "Up next"), accessory: { SeeAllButton(title: String(localized: "Full agenda")) }, content: {
                ForEach(soon.prefix(5)) { entry in
                    SessionRow(entry: entry, now: now, style: .upNext, clash: false)
                }
            })
        }
    }

    /// Between days, after the last session and before the next day's first: the first three sessions of the next day.
    @ViewBuilder private func tomorrow(after next: Date, now: Date) -> some View {
        let day = Lisbon.day(next)
        let first = reader.agenda.filter { event in
            guard let start = event.start else { return false }
            return Lisbon.day(start) == day && start > now && !event.title.localizedCaseInsensitiveContains("registration")
        }.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }.prefix(3)
        if !first.isEmpty {
            TitledCard(String(localized: "Tomorrow"), accessory: { SeeAllButton(title: String(localized: "Full agenda")) }, content: {
                ForEach(Array(first), id: \.id) { event in
                    if let start = event.start {
                        SessionRow(entry: NowBoard.Entry(id: ScheduleID.fromPage(event.page) ?? event.page, title: event.title,
                                                         place: event.place, start: start,
                                                         end: event.end ?? start.addingTimeInterval(1800),
                                                         mine: reader.isSaved(event), url: event.url),
                                   now: now, style: .upNext, clash: false)
                    }
                }
            })
        }
    }

    // MARK: State C, after the summit

    private var thanks: some View {
        let count = reader.saved.count
        return TitledCard(String(localized: "Thanks for coming"), kicker: "Lisbon · 9–12 Nov") {
            Text(count == 0 ? String(localized: "The summit is over. The news and the agenda stay on this phone.")
                 : count == 1 ? String(localized: "You picked 1 talk. The news and the agenda stay on this phone.")
                 : String(localized: "You picked \(count) talks. The news and the agenda stay on this phone."))
                .font(.subheadline).foregroundStyle(Palette.muted)
        }
    }
}

// MARK: - Pieces

/// "Full agenda", "See all" and similar buttons that open Explore.
private struct SeeAllButton: View {
    let title: String
    @Environment(\.openDestination) private var open

    var body: some View {
        Button(title) { open("explore") }.font(.subheadline)
    }
}

/// NOW-1b: with no picks yet.
private struct StartProgramCard: View {
    @Environment(\.openDestination) private var open

    var body: some View {
        TitledCard(String(localized: "Start your program")) {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Pick the talks you want. We'll warn you about clashes and remind you before each one.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                Button { open("explore") } label: {
                    Label("Choose talks", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("pt.now.chooseTalks")
            }
        }
    }
}

/// NOW-1h: Ask about the summit, the last card in every state. iPhone pushes Ask; iPad selects the sidebar's Ask row.
private struct AskCard: View {
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.openDestination) private var open

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.m) {
                    Image(systemName: "sparkles").font(.title3).foregroundStyle(Palette.red).accessibilityHidden(true)
                    Text("Ask about the summit").font(Typo.headline).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                Text("What's on now, what clashes in my program, what's new today. Uses your own OpenRouter key.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                if width == .compact {
                    NavigationLink {
                        AskView().destinationID("collab.ai")
                    } label: {
                        Text("Ask").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pt.now.ask")
                } else {
                    Button { open("collab.ai") } label: {
                        Text("Ask").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pt.now.ask")
                }
            }
        }
    }
}

/// A session row: the time in a fixed column, the title, and one line that depends on where the row is shown.
private struct SessionRow: View {
    enum Style { case forYou, onNow, upNext }

    let entry: NowBoard.Entry
    let now: Date
    let style: Style
    let clash: Bool

    @Environment(ReaderStore.self) private var reader
    @Environment(ScheduleStore.self) private var schedule

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Text(Lisbon.timeLabel(entry.start))
                .font(Typo.data).foregroundStyle(Palette.ink)
                .frame(width: 64, alignment: .leading)
            link {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Space.xs) {
                        if entry.isLive(at: now) {
                            Circle().fill(Palette.red).frame(width: 7, height: 7).accessibilityHidden(true)
                        }
                        Text(entry.title).font(style == .forYou ? Typo.headline : .subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    }
                    Text(detail).font(Typo.data).foregroundStyle(Palette.muted).multilineTextAlignment(.leading)
                    if clash {
                        Text("Clash").font(.caption.weight(.semibold)).foregroundStyle(Palette.amber)
                    }
                }
            }
            Spacer(minLength: Space.xs)
            Button { toggle() } label: {
                Image(systemName: entry.mine ? "star.fill" : "star")
                    .foregroundStyle(entry.mine ? Palette.red : Palette.muted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.mine ? LocalizedStringKey("Remove from my program") : LocalizedStringKey("Add to my program"))
        }
        .accessibilityElement(children: .contain)
    }

    private var detail: String {
        var parts: [String] = []
        if entry.isLive(at: now) {
            let end = Lisbon.timeLabel(entry.end)
            parts.append(String(localized: "until \(end)"))
        } else {
            let minutes = entry.minutesUntilStart(from: now)
            if minutes < 1 {
                parts.append(String(localized: "starting now"))
            } else if minutes < 90 {
                parts.append(String(localized: "in \(minutes) min"))
            } else {
                let hours = minutes / 60
                parts.append(String(localized: "in \(hours) h"))
            }
        }
        if !entry.place.isEmpty { parts.append(entry.place) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func link<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let url = entry.url {
            NavigationLink { WebPage(url: url, title: entry.title) } label: { content().frame(maxWidth: .infinity, alignment: .leading) }
                .buttonStyle(.plain)
        } else {
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toggle() {
        // The entry's id is the schedule slug; the agenda's events are keyed by their page.
        if let event = reader.agenda.first(where: { ScheduleID.fromPage($0.page) == entry.id }) {
            reader.toggleSaved(event)
        } else {
            schedule.toggle(entry.id)
        }
    }
}

/// A row that opens an event's page on the site.
private struct EventLink<Content: View>: View {
    let event: Event
    @ViewBuilder let content: () -> Content

    var body: some View {
        if let url = event.url {
            NavigationLink { WebPage(url: url, title: event.title) } label: { content().frame(maxWidth: .infinity, alignment: .leading) }
                .buttonStyle(.plain)
        } else {
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// NOW-1d: the three newest items from the feed, from the saved copy when offline.
private struct LatestNewsCard: View {
    @Environment(ReaderStore.self) private var reader

    var body: some View {
        let stories = Array(reader.news.prefix(3))
        TitledCard(String(localized: "Latest news"), accessory: {
            NavigationLink("All news") { NewsHomeView() }.font(.subheadline)
        }, content: {
            if stories.isEmpty {
                Text(reader.newsUnavailable
                     ? LocalizedStringKey("The news could not be loaded. Pull down to try again.")
                     : LocalizedStringKey("Loading the news…"))
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            ForEach(stories) { story in
                NavigationLink { WebPage(url: story.url, title: story.title) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(story.title).font(Typo.headline).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        if !story.summary.isEmpty {
                            Text(story.summary).font(.footnote).foregroundStyle(Palette.muted).lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        if let published = story.published {
                            Text(published, format: .relative(presentation: .named))
                                .font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        })
    }
}

/// The practical card (NOW-1e): a fixed list shipped in the app, final copy from the ux spec. Each row with a link opens
/// it in Safari; the registration row opens Explore.
struct PracticalCard: View {
    private struct Row: Identifiable {
        let symbol: String
        let title: LocalizedStringKey
        let line: LocalizedStringKey
        let link: URL?
        var id: String { symbol }
    }

    private let rows: [Row] = [
        Row(symbol: "person.text.rectangle", title: "Registration",
            line: "Collect your badge at Airport Terminal 1 (9–10 Nov) or Pavilhão de Portugal (9–12 Nov). Bring your ticket QR and photo ID.",
            link: nil),
        Row(symbol: "tram.fill", title: "Metro", line: "Red line to Oriente, next to the venue. A summit transport pass is on sale.",
            link: URL(string: "https://www.metrolisboa.pt/2026/11/02/passe-de-transporte-para-web-summit/")),
        Row(symbol: "car.fill", title: "Traffic", line: "Roads around Parque das Nações are restricted 9–12 Nov.",
            link: URL(string: "https://www.jf-parquedasnacoes.pt/autarquia/noticias/web-summit-condicionamentos-de-transito-entre-9-e-12-de-novembro")),
        Row(symbol: "bus.fill", title: "Buses", line: "Carris runs extra buses to Oriente during the summit.",
            link: URL(string: "https://www.carris.pt/")),
        Row(symbol: "map", title: "Venue map", line: "FIL, MEO Arena and Pavilhão de Portugal, with what is on in each.",
            link: URL(string: "https://promptugal.news/summit/venue/index.html")),
        Row(symbol: "phone.fill", title: "Emergency", line: "Call 112.", link: URL(string: "tel:112")),
    ]

    @Environment(\.openDestination) private var open

    var body: some View {
        TitledCard(String(localized: "Practical"), kicker: "Lisbon · 9–12 Nov") {
            VStack(alignment: .leading, spacing: Space.m) {
                ForEach(rows) { row in
                    if let link = row.link {
                        Link(destination: link) { content(row, chevron: true) }
                            .buttonStyle(.plain)
                    } else {
                        Button { open("explore") } label: { content(row, chevron: true) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func content(_ row: Row, chevron: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: row.symbol).foregroundStyle(Palette.muted).frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(row.line).font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.leading)
            }
            Spacer(minLength: Space.xs)
            if chevron {
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.muted).accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Now · iPhone") {
    NavigationStack { NowView() }.environment(ReaderStore()).phonePreview()
}
