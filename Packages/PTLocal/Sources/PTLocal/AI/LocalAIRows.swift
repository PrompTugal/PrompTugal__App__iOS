import PTCore
import SwiftUI

// Rows for the AI pieces, self-contained so they fit any host (the Ask and summarise screen today, the Places
// reader's town page later): serif headlines and the town's accent, as PTPlaces draws them.

/// A story: the headline opens the source; the AI path says why it is here; a sparkles button asks Apple Intelligence.
public struct AIStoryRow: View {
    let story: PlaceSite.News
    let town: String?
    var match: PersonaMatch
    var townForAI: String?

    public init(story: PlaceSite.News, town: String?, match: PersonaMatch = .none, townForAI: String? = nil) {
        self.story = story
        self.town = town
        self.match = match
        self.townForAI = townForAI
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Space.xs) {
            VStack(alignment: .leading, spacing: 4) {
                PersonaMatchChip(match: match)
                if let town { Kicker(town) }
                if let url = story.sourceURL {
                    Link(destination: url) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(story.title).font(Typo.story).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                            Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                } else {
                    Text(story.title).font(Typo.story).foregroundStyle(Palette.ink)
                }
                if let summary = story.summary {
                    Text(summary).font(.system(.footnote, design: .serif)).foregroundStyle(Palette.ink.opacity(0.8)).lineLimit(4)
                }
                HStack(spacing: Space.s) {
                    Text([story.publisher, story.date].compactMap { $0 }.joined(separator: ", "))
                    if let steps = story.stepsLabel { Text("AI path: \(steps)").foregroundStyle(Palette.blue) }
                }
                .font(.caption)
                .foregroundStyle(Palette.muted)
                if let path = story.aiPath {
                    Text(path).font(.caption).italic().foregroundStyle(Palette.muted).lineLimit(3)
                }
            }
            .padding(.leading, match.isMatch ? Space.s : 0)
            .overlay(alignment: .leading) {
                if match.isMatch { Rectangle().fill(Palette.green).frame(width: 3) }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            StorySummaryButton(story: story, town: town ?? townForAI)
        }
        .padding(.vertical, 4)
    }
}

/// An organisation on a town's AI map, with its source.
public struct AIEntryRow: View {
    let entry: PlaceSite.MapEntry
    var match: PersonaMatch

    public init(entry: PlaceSite.MapEntry, match: PersonaMatch = .none) {
        self.entry = entry
        self.match = match
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            PersonaMatchChip(match: match)
            HStack(alignment: .firstTextBaseline) {
                if let home = entry.home {
                    Link(entry.name, destination: home).font(.body.weight(.semibold))
                } else {
                    Text(entry.name).font(.body.weight(.semibold))
                }
                Spacer(minLength: Space.s)
                if let type = entry.type { Text(type).font(.caption2).foregroundStyle(Palette.muted) }
            }
            if let what = entry.what { Text(what).font(.footnote).foregroundStyle(Palette.ink).lineLimit(4) }
            if let path = entry.aiPath { Text("AI path: \(path)").font(.caption).foregroundStyle(Palette.blue).lineLimit(2) }
            HStack(spacing: 4) {
                Image(systemName: "link")
                if let source = entry.source { Link(entry.sourceHost, destination: source) } else { Text(entry.sourceHost) }
                if let read = entry.readOn { Text("· read \(read)") }
            }
            .font(.caption2)
            .foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 4)
    }
}

/// A town's name in its own accent, live or researching, and a link to its site.
struct AITownHeader: View {
    let info: PlaceInfo
    let site: PlaceSite?

    var body: some View {
        let accent = Color(hex: site?.look?.accent)
        HStack(alignment: .center, spacing: Space.m) {
            RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 6, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(Palette.ink)
                Text([site?.look?.landmark, site.map { $0.isLive ? "Live site" : "Researching" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer(minLength: Space.s)
            Link(destination: info.page) {
                Label("Site", systemImage: "safari").font(.caption)
            }
        }
    }
}
