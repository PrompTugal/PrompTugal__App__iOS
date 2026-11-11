import SwiftUI
import PTCore
import PTFringe

/// The groups behind the events: what each says it is (quoted from its own page), how to join, its public links, and
/// its events this week where the list holds them.
struct CommunitiesView: View {
    @Environment(FringeStore.self) private var store
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if shown.isEmpty {
                    Section {
                        Text(store.communities.isEmpty
                             ? (store.communitiesUnavailable ? "Communities could not be loaded yet. They are kept on this phone once they have been." : "Loading communities.")
                             : "No community matches.")
                            .foregroundStyle(Palette.muted)
                    }
                }
                ForEach(shown) { community in
                    NavigationLink(value: community) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(community.name).font(Typo.headline)
                            if !community.about.isEmpty {
                                Text(community.about).font(Typo.meta).foregroundStyle(Palette.muted).lineLimit(2)
                            }
                            let count = store.events(of: community).count
                            if count > 0 { Text(count == 1 ? "1 event listed" : "\(count) events listed").font(Typo.dataSmall).foregroundStyle(Palette.muted) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search communities")
            .refreshable { await store.refresh(force: true) }
            .navigationTitle("Communities")
            .navigationDestination(for: FringeCommunity.self) { CommunityDetail(community: $0) }
            .navigationDestination(for: FringeEvent.self) { EventDetail(event: $0) }
        }
    }

    private var shown: [FringeCommunity] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return store.communities }
        return store.communities.filter { $0.name.localizedCaseInsensitiveContains(text) || $0.about.localizedCaseInsensitiveContains(text) }
    }
}

struct CommunityDetail: View {
    let community: FringeCommunity
    @Environment(FringeStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        let events = store.events(of: community)
        Page(maxWidth: 700) {
            VStack(alignment: .leading, spacing: Space.s) {
                Kicker(String(localized: "Community"))
                Text(community.name).font(Typo.title)
            }
            Card {
                if !community.about.isEmpty {
                    Text(community.about).font(Typo.body)
                    Text(aboutNote).font(Typo.meta).foregroundStyle(Palette.muted)
                } else {
                    Text("It has not published a description we could read.").font(Typo.meta).foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("How to join").font(Typo.kicker).foregroundStyle(Palette.muted)
                    Text(community.joinText ?? "Not published yet.").font(Typo.body)
                }
            }
            if !community.links.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker(String(localized: "Public links"))
                    ForEach(community.links, id: \.url) { link in
                        Button { openURL(link.url) } label: { Label(link.label, systemImage: "safari").frame(maxWidth: .infinity, alignment: .leading) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker(events.count == 1 ? String(localized: "1 event listed") : String(localized: "\(events.count) events listed"))
                    ForEach(events) { event in
                        NavigationLink(value: event) { Card { EventRow(event: event, showDay: true) } }.buttonStyle(.plain)
                    }
                }
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Where the description comes from and when it was read.
    private var aboutNote: String {
        var parts = ["Quoted from the community's own page"]
        if let host = community.aboutSource?.host { parts[0] += " (\(host))" }
        if let read = community.aboutReadAt.flatMap({ ISO8601DateFormatter().date(from: $0) }) {
            parts.append("read \(FringeFilter.dayLabel(Lisbon.day(read))), \(Lisbon.timeLabel(read))")
        }
        return parts.joined(separator: ", ") + "."
    }
}
