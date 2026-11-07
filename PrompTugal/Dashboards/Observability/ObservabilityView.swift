import SwiftUI

/// Observability, native. Being built.
struct ObservabilityView: View {
    var body: some View {
        WebPage(url: FeedClient.site.appendingPathComponent("newsroom/observability/"), title: "Observability")
    }
}
