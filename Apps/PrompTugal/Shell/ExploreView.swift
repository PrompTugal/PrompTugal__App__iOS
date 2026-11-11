import PTAgenda
import PTCore
import PTExplore
import PTNews
import PTWeb
import SwiftUI

/// Where Explore opens. The shell sets it from the id that was opened (explore, explore.people, explore.talk, ...).
private struct ExploreStartKey: EnvironmentKey {
    static let defaultValue: ExploreStart = .talks
}

extension EnvironmentValues {
    var exploreStart: ExploreStart {
        get { self[ExploreStartKey.self] }
        set { self[ExploreStartKey.self] = newValue }
    }
}

/// Explore (ux spec EXP-1): PTExplore's screen with the app's views plugged in: the agenda list for Talks (PTExplore cannot
/// see PTAgenda), the shared talk detail with the pick star and Add to Calendar, the graph card once there are three picks,
/// and the graph itself. The screen brings its own navigation stack.
struct ExploreView: View {
    @Environment(\.exploreStart) private var start
    @Environment(ReaderStore.self) private var reader
    @Environment(\.openMore) private var openMore
    @State private var opened: TalkSheetItem?

    var body: some View {
        ExploreScreen(hooks: hooks, start: start)
            // A different start (a link to another segment) builds the screen again at that segment.
            .id(Self.key(start))
            .talkSheet($opened)
    }

    private var hooks: ExploreHooks {
        ExploreHooks(
            talks: { AnyView(AgendaView(title: String(localized: "Explore"), openSession: { opened = TalkSheetItem(talk: TalkRef($0)) })) },
            header: { AnyView(GraphCard(picks: reader.saved.count)) },
            graph: { AnyView(GraphExplorerView()) },
            talkActions: AppTalks.actions,
            leadingToolbar: { AnyView(LanguageButton()) },
            trailingToolbar: moreButton)
    }

    /// The More button on iPhone; nil on iPad, where More is in the sidebar.
    private var moreButton: (@MainActor () -> AnyView)? {
        guard let openMore else { return nil }
        return { AnyView(MoreButton(action: openMore)) }
    }

    private static func key(_ start: ExploreStart) -> String {
        switch start {
        case .talks: "talks"
        case .speakers: "speakers"
        case .companies: "companies"
        case .places: "places"
        case .talk(let ref): "talk:" + (ref ?? "")
        case .graph: "graph"
        }
    }
}

/// EXP-G: the graph, offered once the person has three or more picks (no empty graphs). The scoped graph (only the people
/// and companies behind the picks) is not built yet, so the card opens the full graph and says so.
private struct GraphCard: View {
    let picks: Int

    var body: some View {
        if picks >= 3 {
            NavigationLink {
                GraphExplorerView()
            } label: {
                Card {
                    HStack(spacing: Space.m) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2).foregroundStyle(Palette.red)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Explore the summit graph").font(Typo.headline).foregroundStyle(Palette.ink)
                            Text("Companies, people and events").font(.footnote).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: Space.s)
                        Image(systemName: "chevron.forward").font(.footnote).foregroundStyle(Palette.muted)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Space.l)
            .accessibilityIdentifier("pt.explore.graph")
        }
    }
}
