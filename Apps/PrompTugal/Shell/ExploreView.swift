import PTAgenda
import PTCore
import PTExplore
import PTNews
import PTWeb
import SwiftUI

/// Where Explore opens. The shell sets it from the id that was opened (explore, explore.people, explore.talk, ...).
private struct ExploreStartKey: EnvironmentKey {
    static let defaultValue: ExploreStart = .stories
}

extension EnvironmentValues {
    var exploreStart: ExploreStart {
        get { self[ExploreStartKey.self] }
        set { self[ExploreStartKey.self] = newValue }
    }
}

/// Explore (ux spec EXP-1), rebuilt for the newsroom (25 Nov): PTExplore's screen on the newsroom's own sites (stories,
/// companies and places from promptugal.news, the library and the videos), each list ending with the newsroom's graph.
/// Nothing from the summit (Dinis, 25 Nov). The screen brings its own navigation stack.
struct ExploreView: View {
    @Environment(\.exploreStart) private var start
    @Environment(\.openMore) private var openMore

    var body: some View {
        ExploreScreen(store: ExploreStore.newsroom(), hooks: hooks, start: start)
            // A different start (a link to another segment) builds the screen again at that segment.
            .id(Self.key(start))
    }

    private var hooks: ExploreHooks {
        ExploreHooks(
            graph: { AnyView(GraphExplorerView()) },
            trailingToolbar: moreButton,
            showsTalks: false,
            showsGraphRow: true)
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
        case .stories: "stories"
        case .library: "library"
        case .talk(let ref): "talk:" + (ref ?? "")
        case .graph: "graph"
        }
    }
}
