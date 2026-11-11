import SwiftUI
import PTAgenda
import PTCore
import PTFringe

/// Now and next, and the storm block. The clock is PTAgenda's (real time unless a test fixes it).
struct NowView: View {
    @Environment(FringeStore.self) private var store

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let model = FringeNow(events: store.events, now: AgendaClock.override ?? context.date)
                Page(maxWidth: 700) {
                    StormBlock(storm: store.storm, unavailable: store.stormUnavailable)
                    section(String(localized: "On now"), model.onNow, empty: String(localized: "Nothing published as on right now."))
                    section(String(localized: "Next today"), model.next, empty: String(localized: "Nothing later today is published yet."))
                    if !model.untimed.isEmpty {
                        section(String(localized: "Today, time not published"), model.untimed, empty: "")
                    }
                    FreshnessNote()
                }
                .refreshable { await store.refresh(force: true) }
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Now")
            .navigationDestination(for: FringeEvent.self) { EventDetail(event: $0) }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ events: [FringeEvent], empty: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Kicker(title)
            if events.isEmpty {
                Text(empty).font(Typo.meta).foregroundStyle(Palette.muted)
            } else {
                ForEach(events) { event in
                    NavigationLink(value: event) { Card { EventRow(event: event) } }.buttonStyle(.plain)
                }
            }
        }
    }
}

/// Storm Charles, from the storm site: the headline and its source, with links to IPMA and ANEPC. Not a warning service.
struct StormBlock: View {
    let storm: StormHeadline?
    let unavailable: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        Card {
            Kicker(String(localized: "Storm Charles"), color: Palette.amber)
            if let storm {
                Text(storm.text).font(Typo.headline)
                if !storm.source.isEmpty {
                    Text(storm.at.isEmpty ? storm.source : "\(storm.source), \(storm.at)").font(Typo.meta).foregroundStyle(Palette.muted)
                }
            } else {
                Text(unavailable ? "The storm update could not be loaded." : "Loading the storm update.").font(Typo.body)
            }
            Text("This is not a warning service. For warnings follow IPMA and ANEPC.").font(Typo.meta).foregroundStyle(Palette.muted)
            HStack {
                Button("IPMA") { openURL(FringeText.ipma) }
                Button("ANEPC") { openURL(FringeText.anepc) }
                Button("Storm site") { openURL(storm?.siteURL ?? FringeText.stormSite) }
            }
            .buttonStyle(.bordered).font(Typo.meta)
        }
    }
}

/// Says where the list comes from, and how old it is.
struct FreshnessNote: View {
    @Environment(FringeStore.self) private var store

    var body: some View {
        Text(text).font(Typo.meta).foregroundStyle(Palette.muted)
    }

    private var text: String {
        switch store.source {
        case .network:
            "Updated \(store.eventsUpdated.map { Lisbon.timeLabel($0) } ?? "just now")."
        case .cache:
            store.eventsUnavailable ? "Showing the last list kept on this phone; the site could not be reached." : "Showing the last list kept on this phone."
        case .seed:
            store.eventsUnavailable ? "Showing the list that came with the app (11 November); the site could not be reached." : "Showing the list that came with the app (11 November) until the site answers."
        }
    }
}
