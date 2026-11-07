import SwiftUI

/// Briefed: my stand-up briefing, the decisions waiting on me (from my command
/// centre and from the newsroom), and what the agents ask of a person.
struct BriefedView: View {
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""
    @AppStorage(SampleMode.key) private var sampleMode = false

    var body: some View {
        let person = data.person(me)
        // Sample people have no command centre on the team site.
        let centre = me.isEmpty || sampleMode ? nil : data.commandCentre(me)
        Page {
            ScreenHeader(kicker: "Briefed", title: person.map { "\($0.first ?? $0.displayName)'s briefing" } ?? "Briefings",
                         summary: "The stand-up briefing, the decisions that wait on you, and what the agents ask.")
            if let person {
                StandupCard(person: person)
            } else {
                GapNote(title: "Who are you?", text: "Choose yourself in Settings to see your own briefing and decisions.")
            }
            Columns {
                if let centre {
                    let mine = (centre.value?.decisions ?? []).filter { decision in
                        guard let who = decision.who?.lowercased(), let first = person?.first?.lowercased() else { return true }
                        return who.contains(first) || who.contains(me.lowercased())
                    }
                    TitledCard("Decisions waiting on me", kicker: "\(mine.count) from my command centre",
                               accessory: { FreshnessLabel(updated: centre.updated, failed: centre.failed) }) {
                        if centre.value == nil {
                            StateView(phase: centre.phase, hasData: false, title: "command centre")
                        }
                        ForEach(mine.prefix(15), id: \.self) { decision in
                            VStack(alignment: .leading, spacing: 3) {
                                InfoRow(title: decision.what ?? "Decision", detail: decision.issue, date: decision.sinceDate,
                                        symbol: "checkmark.circle", tint: Palette.amber)
                                if let recommend = decision.recommend, !recommend.isEmpty {
                                    Text("Recommended: \(recommend)").font(.caption).foregroundStyle(Palette.green)
                                        .padding(.leading, 32)
                                }
                            }
                        }
                    }
                }
                newsroomDecisions
            } trailing: {
                asks
                TitledCard("Newsletters", kicker: "Morning and evening") {
                    ForEach(data.newsletter.value?.editions ?? []) { edition in
                        if let url = edition.pageURL {
                            WebLinkRow(title: edition.title ?? "Edition", url: url, symbol: "envelope.open")
                        }
                    }
                }
                TitledCard("Briefs on the web", kicker: "Web twins") {
                    WebLinkRow(title: "The pulse, summarised", url: TeamSite.base.appendingPathComponent("pulse-summary/"))
                    WebLinkRow(title: "The board's health", url: TeamSite.base.appendingPathComponent("board-health/"))
                    WebLinkRow(title: "Reports every two hours", url: TeamSite.base.appendingPathComponent("reports/"))
                    WebLinkRow(title: "Newsroom decisions", url: FeedClient.site.appendingPathComponent("newsroom/decisions/"))
                }
            }
        }
        .navigationTitle("Briefed")
        .refreshable { await reload(force: true) }
        .task { await reload(force: false) }
        .webTwin(person?.briefingURL ?? TeamSite.base.appendingPathComponent("meetings/"), title: "Briefing")
    }

    private func reload(force: Bool) async {
        async let all: Void = data.refreshAll(force: force)
        if !me.isEmpty, !sampleMode { await data.commandCentre(me).load(force: force) }
        await all
    }

    @ViewBuilder private var newsroomDecisions: some View {
        let open = (data.decisions.value?.decisions ?? []).filter(\.isOpen)
        let shown = me == "dinis" ? open : open.filter { $0.forDinis != true }
        TitledCard("Newsroom decisions", kicker: "\(open.count) open") {
            if data.decisions.value == nil {
                StateView(phase: data.decisions.phase, hasData: false, title: "decisions")
            }
            ForEach(shown) { decision in
                if let url = decision.url {
                    NavigationLink {
                        WebPage(url: url, title: "Decision")
                    } label: {
                        InfoRow(title: decision.title ?? "Decision", detail: decision.blocks,
                                date: WireDate.parse(decision.since),
                                symbol: decision.forDinis == true ? "person.crop.circle.badge.exclamationmark" : "person.3",
                                tint: decision.forDinis == true ? Palette.red : Palette.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var asks: some View {
        let asks = data.dashboard.value?.asks ?? []
        if !asks.isEmpty {
            TitledCard("What the agents ask", kicker: "\(asks.count) asks") {
                ForEach(Array(asks.prefix(12).enumerated()), id: \.offset) { _, ask in
                    InfoRow(title: ask.ask ?? "", detail: ask.from, date: WireDate.parse(ask.since),
                            symbol: "hand.raised", tint: Palette.amber)
                }
                if asks.count > 12 {
                    Text("and \(asks.count - 12) more on the newsroom dashboard").font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

#Preview("Briefed · iPhone") {
    NavigationStack { BriefedView() }.environment(PreviewSamples.data()).phonePreview()
}

#Preview("Briefed · iPad") {
    NavigationStack { BriefedView() }.environment(PreviewSamples.data()).padPreview()
}
