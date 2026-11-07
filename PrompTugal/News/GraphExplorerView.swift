import SwiftUI

/// The graph explorer, drawn natively. Being built.
struct GraphExplorerView: View {
    var body: some View {
        WebPage(url: FeedClient.site.appendingPathComponent("graph/"), title: "Graph")
    }
}
