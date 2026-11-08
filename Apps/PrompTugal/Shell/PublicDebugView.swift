import PTCore
import SwiftUI

#if DEBUG
/// The public app's debug screen, in DEBUG builds only: the build and the requests the app has made.
/// URLs are already redacted by the HTTP client. A Release build has no debug screen.
struct PublicDebugView: View {
    private let log = HTTPLog.shared

    var body: some View {
        List {
            Section("Build") {
                ForEach(BuildInfo.current.rows, id: \.label) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }
            Section("Network") {
                LabeledContent("Requests", value: "\(log.totalRequests)")
                LabeledContent("Failed", value: "\(log.totalFailures)")
                LabeledContent("Downloaded", value: Bytes.format(log.totalBytes))
            }
            Section("Newest requests") {
                if log.records.isEmpty {
                    Text("No requests yet.").foregroundStyle(Palette.muted)
                }
                ForEach(log.records.prefix(50)) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.url).font(.caption).lineLimit(2)
                        Text("\(record.host) · \(Int(record.durationMs)) ms · \(record.succeeded ? "ok" : "failed")")
                            .font(.caption2).foregroundStyle(record.succeeded ? Palette.muted : Palette.red)
                    }
                }
            }
        }
        .navigationTitle("Debug")
    }
}
#else
struct PublicDebugView: View {
    var body: some View { EmptyView() }
}
#endif
