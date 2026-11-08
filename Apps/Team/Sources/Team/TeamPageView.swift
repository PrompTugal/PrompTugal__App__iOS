import SwiftUI

/// A team-site page drawn natively from its markdown twin: reports, the board's health, the pulse summary. The page
/// is kept on the device for offline use; the web page stays one tap away as a fallback.
struct TeamPageView: View {
    let path: String            // "board-health", "reports/2026-11-07-1457"
    let title: String

    @Environment(TeamStore.self) private var team

    private var webURL: URL? { TeamEndpoints.url("\(path)/index.html") }

    var body: some View {
        let page = team.page(path)
        let failed = team.status[TeamStore.pageStatusKey(path)]?.failed == true
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let page {
                    ForEach(page.items) { TeamPageBlockView(block: $0.block, base: webURL) }
                } else if failed {
                    ContentUnavailableView("This page is unavailable", systemImage: "wifi.slash",
                                           description: Text("Connect to the internet and pull to refresh."))
                } else {
                    ProgressView("Loading…").frame(maxWidth: .infinity)
                }
                if let webURL {
                    Divider()
                    Link(destination: webURL) { Label("Open the web page", systemImage: "safari") }
                    Text("From web-summit.sgit.ai, public data, kept on this device for offline use.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await team.refreshPage(path) }
        .task { await team.refreshPage(path) }
    }
}

/// One block of a team page.
struct TeamPageBlockView: View {
    let block: TeamPageBlock
    let base: URL?

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(TeamInline.attributed(text, base: base))
                .font(Self.font(level))
                .padding(.top, level <= 2 ? 8 : 4)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(TeamInline.attributed(text, base: base))
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(TeamInline.attributed(item, base: base))
                    }
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).").monospacedDigit()
                        Text(TeamInline.attributed(item, base: base))
                    }
                }
            }
        case .table(let header, let rows):
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                            Text(TeamInline.attributed(cell, base: base)).bold()
                        }
                    }
                    Divider()
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                Text(TeamInline.attributed(cell, base: base))
                            }
                        }
                    }
                }
                .font(.subheadline)
            }
        case .quote(let text):
            HStack(spacing: 10) {
                Rectangle().fill(Color.secondary).frame(width: 3)
                Text(TeamInline.attributed(text, base: base)).foregroundStyle(.secondary)
            }
        case .code(let text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
            }
        case .rule:
            Divider()
        }
    }

    private static func font(_ level: Int) -> Font {
        switch level {
        case 1: .title.bold()
        case 2: .title2.bold()
        case 3: .title3.bold()
        default: .headline
        }
    }
}

enum TeamInline {
    /// Inline markdown (bold, italics, code, links) as styled text. A relative link ("../reports/x/index.html")
    /// is made absolute against the page it is on, so a tap opens the team site.
    static func attributed(_ markdown: String, base: URL?) -> AttributedString {
        var text = (try? AttributedString(markdown: markdown,
                                          options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
        guard let base else { return text }
        var edits: [(Range<AttributedString.Index>, URL)] = []
        for run in text.runs {
            guard let link = run.link, link.scheme == nil,
                  let resolved = URL(string: link.relativeString, relativeTo: base)?.absoluteURL else { continue }
            edits.append((run.range, resolved))
        }
        for (range, url) in edits { text[range].link = url }
        return text
    }
}
