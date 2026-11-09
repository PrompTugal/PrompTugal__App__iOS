import PTAgenda
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
/// agenda (`NowModel`, PTAgenda): before the summit a countdown, during it For you, On now and Up next, between days
/// Tomorrow, after it a thank you. The latest news, the practical card and the Ask card are in every phase.
/// Every user-facing string is written exactly as in the ux spec, so the String Catalog keys match.
struct NowView: View {
    @Environment(ReaderStore.self) private var reader
    var body: some View {
        // One minute at a time: the clock, the model and the countdowns follow it. `-PTNow` fixes the time in DEBUG builds.
        TimelineView(.everyMinute) { context in
            let now = AgendaClock.override ?? context.date
            let model = reader.nowModel(at: now)
            Page(maxWidth: Space.readable) {
                header(now: now)
                if reader.agenda.isEmpty {
                    agendaMissing
                } else {
                    switch model.phase {
                    case .before:
                        countdown(model)
                        startProgram(model, now: now)
                    case .during:
                        forYou(model, now: now)
                        onNow(model, now: now)
                        upNext(model, now: now)
                    case .between:
                        forYou(model, now: now)
                        tomorrow(model, now: now)
                    case .after:
                        thanks(count: model.pickCount)
                    }
                }
                LatestNewsCard()
                PracticalCard()
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
            Kicker(String(localized: "Lisbon · \(now.formatted(Self.dayStyle)) · \(Lisbon.timeLabel(now))"))
                .accessibilityLabel(String(localized: "Lisbon, \(now.formatted(Self.dayStyle)) at \(Lisbon.timeLabel(now))"))
            FreshnessLabel(updated: reader.agendaUpdated ?? reader.newsUpdated,
                           failed: reader.agendaUnavailable || reader.newsUnavailable)
        }
    }

    /// Computed, not stored: the chosen culture can change while the app runs.
    private static var dayStyle: Date.FormatStyle {
        var style = Date.FormatStyle().locale(AppCulture.locale).weekday(.wide).day().month(.wide)
        style.timeZone = Lisbon.zone
        return style
    }

    /// No agenda yet (the first launch offline, or still loading): a loading or failed state with "Try again", never a blank screen.
    private var agendaMissing: some View {
        StateView(phase: reader.agendaUnavailable ? .failed(String(localized: "The agenda could not be loaded.")) : .loading,
                  hasData: false, title: String(localized: "the agenda")) { Task { await reader.refresh() } }
    }

    // MARK: State A, before the summit

    private func countdown(_ model: NowModel) -> some View {
        TitledCard(Self.countdownTitle(model.countdown), kicker: String(localized: "Lisbon · 9–12 Nov")) {
            VStack(alignment: .leading, spacing: Space.m) {
                ForEach(model.firstItems) { entry in
                    EntryLink(entry: entry) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                            Text(Self.whenAndWhere(entry)).font(Typo.data).foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
        }
    }

    /// "The summit starts in 1 day" (or 5 hours, 20 minutes): the largest whole unit, from team's model.
    static func countdownTitle(_ countdown: NowModel.Countdown?) -> String {
        guard let countdown else { return String(localized: "The summit starts soon") }
        let value = countdown.largest.value
        switch countdown.largest.unit {
        case .days:
            return value == 1 ? String(localized: "The summit starts in 1 day") : String(localized: "The summit starts in \(value) days")
        case .hours:
            return value == 1 ? String(localized: "The summit starts in 1 hour") : String(localized: "The summit starts in \(value) hours")
        case .minutes:
            return value == 1 ? String(localized: "The summit starts in 1 minute")
                : String(localized: "The summit starts in \(value) minutes")
        }
    }

    private static func whenAndWhere(_ entry: NowModel.Entry) -> String {
        let day = entry.start.formatted(Self.shortDayStyle)
        return [day + ", " + Lisbon.timeLabel(entry.start), entry.place].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static var shortDayStyle: Date.FormatStyle {
        var style = Date.FormatStyle().locale(AppCulture.locale).weekday(.abbreviated).day().month(.abbreviated)
        style.timeZone = Lisbon.zone
        return style
    }

    /// NOW-1b: with no picks, a card that starts the program; with picks, the next one.
    @ViewBuilder private func startProgram(_ model: NowModel, now: Date) -> some View {
        if model.pickCount == 0 {
            StartProgramCard()
        } else {
            forYou(model, now: now)
        }
    }

    // MARK: State B, during the summit

    /// NOW-1c: my current pick, or my next one.
    @ViewBuilder private func forYou(_ model: NowModel, now: Date) -> some View {
        if let forYou = model.forYou {
            TitledCard(String(localized: "For you"),
                       kicker: forYou.isNow ? String(localized: "On now") : String(localized: "Next in your program")) {
                SessionRow(entry: forYou.entry, now: now, style: .forYou, clash: forYou.clashes)
            }
        } else if model.phase == .during {
            StartProgramCard()
        }
    }

    /// NOW-1f: up to five sessions running now, Centre Stage first (the model sorts them).
    @ViewBuilder private func onNow(_ model: NowModel, now: Date) -> some View {
        let running = model.onNow
        if !running.isEmpty {
            TitledCard(String(localized: "On now at the venue"), accessory: {
                if model.onNowCount > running.count {
                    SeeAllButton(title: String(localized: "See all (\(model.onNowCount))"))
                }
            }, content: {
                ForEach(running) { entry in
                    SessionRow(entry: entry, now: now, style: .onNow, clash: false)
                }
            })
        }
    }

    /// NOW-1g: up to five sessions starting in the next 60 minutes.
    @ViewBuilder private func upNext(_ model: NowModel, now: Date) -> some View {
        let soon = model.upNext
        if !soon.isEmpty {
            TitledCard(String(localized: "Up next"), accessory: { SeeAllButton(title: String(localized: "Full agenda")) }, content: {
                ForEach(soon) { entry in
                    SessionRow(entry: entry, now: now, style: .upNext, clash: false)
                }
            })
        }
    }

    /// Between days: the first three sessions of the next day.
    @ViewBuilder private func tomorrow(_ model: NowModel, now: Date) -> some View {
        let first = model.tomorrow
        if !first.isEmpty {
            TitledCard(String(localized: "Tomorrow"), accessory: { SeeAllButton(title: String(localized: "Full agenda")) }, content: {
                ForEach(first) { entry in
                    SessionRow(entry: entry, now: now, style: .upNext, clash: false)
                }
            })
        }
    }

    // MARK: State C, after the summit

    private func thanks(count: Int) -> some View {
        TitledCard(String(localized: "Thanks for coming"), kicker: String(localized: "Lisbon · 9–12 Nov")) {
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

/// A session row: the time in a fixed column, the title, and one line that depends on where the row is shown.
private struct SessionRow: View {
    enum Style { case forYou, onNow, upNext }

    let entry: NowModel.Entry
    let now: Date
    let style: Style
    let clash: Bool

    @Environment(ReaderStore.self) private var reader
    @Environment(ScheduleStore.self) private var schedule

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            // The column is as wide as "88:88 AM" (12-hour locales), so a time never wraps and the rows line up.
            Text(verbatim: "88:88 AM").font(Typo.data).lineLimit(1).fixedSize(horizontal: true, vertical: false).hidden()
                .overlay(alignment: .leading) {
                    Text(Lisbon.timeLabel(entry.start))
                        .font(Typo.data).foregroundStyle(Palette.ink)
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
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

/// A row that opens a session's page on the site.
private struct EntryLink<Content: View>: View {
    let entry: NowModel.Entry
    @ViewBuilder let content: () -> Content

    var body: some View {
        if let url = entry.url {
            NavigationLink { WebPage(url: url, title: entry.title) } label: { content().frame(maxWidth: .infinity, alignment: .leading) }
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
        TitledCard(String(localized: "Practical"), kicker: String(localized: "Lisbon · 9–12 Nov")) {
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
