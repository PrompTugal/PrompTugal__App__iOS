import PTAgenda
import PTAsk
import PTCore
import PTNews
import PTWeb
import SwiftUI

/// Now (ux spec NOW-1): the first screen. This is the shell milestone: the header with Lisbon time, the Ask card,
/// the latest three news items and the practical card. The three states (before, during, after the summit),
/// For you, On now and Up next follow when `NowModel` (PTAgenda) lands.
struct NowView: View {
    @Environment(ReaderStore.self) private var reader

    var body: some View {
        Page(maxWidth: 900) {
            header
            askCard
            latestNews
            PracticalCard()
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle("Now")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reader.refresh() }
    }

    // MARK: Header: the date and the time in Lisbon, then how fresh the data is

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Kicker("Lisbon · " + context.date.formatted(Self.dayStyle))
                    Text(Lisbon.timeLabel(context.date))
                        .font(Typo.display)
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                        .accessibilityLabel("Time in Lisbon, " + Lisbon.timeLabel(context.date))
                }
            }
            FreshnessLabel(updated: reader.agendaUpdated ?? reader.newsUpdated,
                           failed: reader.agendaUnavailable || reader.newsUnavailable)
        }
    }

    private static let dayStyle: Date.FormatStyle = {
        var style = Date.FormatStyle().weekday(.wide).day().month(.wide)
        style.timeZone = Lisbon.zone
        return style
    }()

    // MARK: Ask

    private var askCard: some View {
        NavigationLink {
            AskView().destinationID("collab.ai")
        } label: {
            Card {
                HStack(spacing: Space.m) {
                    Image(systemName: "sparkles").font(.title3).foregroundStyle(Palette.red).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ask about the summit").font(Typo.headline).foregroundStyle(Palette.ink)
                        Text("What's on now, what's next in your program, what's new. Uses your own OpenRouter key.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: Space.s)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pt.now.ask")
    }

    // MARK: Latest news (NOW-1d)

    @ViewBuilder private var latestNews: some View {
        let stories = Array(reader.news.prefix(3))
        TitledCard("Latest news", accessory: {
            NavigationLink("All news") { NewsHomeView() }.font(.subheadline)
        }, content: {
            if stories.isEmpty {
                Text(reader.newsUnavailable ? "The news could not be loaded. Pull down to try again." : "Loading the news…")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            ForEach(stories) { story in
                NavigationLink { WebPage(url: story.url, title: "Story") } label: {
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

/// The practical card (NOW-1e): fixed text shipped in the app. Source links are added when ux confirms them.
struct PracticalCard: View {
    private let rows: [(symbol: String, title: String, text: String)] = [
        ("person.text.rectangle", "Registration",
         "Collect your lanyard: Airport T1 (9–10 Nov) or Pavilhão de Portugal (9–12 Nov). Bring your ticket QR and photo ID."),
        ("tram.fill", "Getting there", "Metro: red line to Oriente."),
        ("car.fill", "Traffic", "Road closures around Parque das Nações, 9–12 Nov."),
        ("bus.fill", "Shuttle", "Carris shuttle for participants."),
    ]

    var body: some View {
        TitledCard("Practical", kicker: "Lisbon · 9–12 Nov") {
            VStack(alignment: .leading, spacing: Space.m) {
                ForEach(rows, id: \.title) { row in
                    HStack(alignment: .top, spacing: Space.m) {
                        Image(systemName: row.symbol).foregroundStyle(Palette.muted).frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                            Text(row.text).font(.footnote).foregroundStyle(Palette.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview("Now · iPhone") {
    NavigationStack { NowView() }.environment(ReaderStore()).phonePreview()
}
