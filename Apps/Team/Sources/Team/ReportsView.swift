import SwiftUI

/// The reports every two hours and the newsletters, native. Each opens as a native page; the list is kept on the
/// device from the team site's `/reports/` twin.
struct ReportsView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity

    var body: some View {
        let newsletters = team.reports.filter(\.isNewsletter)
        let reports = team.reports.filter { !$0.isNewsletter }
        List {
            if team.reports.isEmpty {
                Section {
                    if team.refreshing {
                        ProgressView("Loading the reports…")
                    } else {
                        ContentUnavailableView("The reports are unavailable", systemImage: "wifi.slash",
                                               description: Text("Connect to the internet and pull to refresh."))
                    }
                }
            }
            if !newsletters.isEmpty {
                Section("Newsletters") { ForEach(newsletters) { row($0) } }
            }
            if !reports.isEmpty {
                Section("What happened, every two hours") { ForEach(reports) { row($0) } }
            }
            Section {
                Link(destination: TeamEndpoints.base.appendingPathComponent("reports/")) {
                    Label("Open the web page", systemImage: "safari")
                }
            } footer: {
                Text("From web-summit.sgit.ai, public data, kept on this device for offline use.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reports")
        .refreshable { await team.refresh(person: identity.current?.id) }
        .task { if team.reports.isEmpty { await team.refresh(person: identity.current?.id) } }
    }

    private func row(_ report: TeamReport) -> some View {
        NavigationLink {
            TeamPageView(path: "reports/" + Self.slug(report), title: Self.shortTitle(report))
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(report.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                if !report.summary.isEmpty {
                    Text(report.summary).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// "2026-11-07-1457/index.html" → "2026-11-07-1457".
    static func slug(_ report: TeamReport) -> String {
        report.path.hasSuffix("/index.html") ? String(report.path.dropLast("/index.html".count)) : report.path
    }

    /// "What happened: Saturday 7 November, 14:57" → "Saturday 7 November, 14:57".
    static func shortTitle(_ report: TeamReport) -> String {
        guard let colon = report.title.firstIndex(of: ":") else { return report.title }
        return report.title[report.title.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    }
}
