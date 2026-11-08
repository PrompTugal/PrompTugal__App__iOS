import SGitVault
import SwiftUI

/// Debug mode (contract §8): every panel, with a live summary on its card.
struct DebugHomeView: View {
    @Environment(DashboardData.self) private var data
    @Environment(VaultTrafficLog.self) private var vaultLog: VaultTrafficLog?
    private let http = HTTPLog.shared

    var body: some View {
        Page {
            ScreenHeader(kicker: "Debug", title: "How the app works",
                         summary: "Every request, every vault object, every bridge message, what is stored and which keys exist. Never a key's value.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Space.m)], spacing: Space.m) {
                panel("Network", symbol: "network", tint: Palette.blue,
                      line: "\(http.totalRequests) requests · \(Bytes.format(http.totalBytes)) · \(http.totalFailures) failed") {
                    NetworkPanel()
                }
                panel("Vault traffic", symbol: "lock.shield", tint: Palette.green,
                      line: vaultLog.map { "\($0.events.count) events · \(Bytes.format($0.events.reduce(0) { $0 + $1.bytes }))" }
                        ?? "No vault open") {
                    VaultTrafficPanel()
                }
                panel("Bridge", symbol: "arrow.left.arrow.right", tint: Palette.amber, line: "Web page ↔ app messages") {
                    BridgePanel()
                }
                panel("Storage", symbol: "internaldrive", tint: Palette.series(4),
                      line: "\(data.feedSummaries.filter { $0.bytes > 0 }.count) feeds cached") {
                    StoragePanel()
                }
                panel("Keys", symbol: "key", tint: Palette.red, line: "Which keys exist, and where. Never values") {
                    KeysPanel()
                }
                panel("Collaboration and AI", symbol: "sparkles", tint: Palette.series(5),
                      line: "Ask requests, lanes log, which secrets exist") {
                    CollabDebugPanel()
                }
                panel("Native and web", symbol: "square.split.2x1", tint: Palette.green,
                      line: "\(Destinations.all.filter { $0.kind == .native }.count) of \(Destinations.all.count) screens native") {
                    BalancePanel()
                }
                panel("Build", symbol: "hammer", tint: Palette.muted,
                      line: "\(BuildInfo.current.appVersion) · \(BuildInfo.current.shortCommit)") {
                    BuildPanel()
                }
            }
        }
        .navigationTitle("Debug")
    }

    private func panel<Destination: View>(_ title: String, symbol: String, tint: Color, line: String,
                                          @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            Card {
                HStack(spacing: Space.m) {
                    Image(systemName: symbol).font(.title2).foregroundStyle(tint).frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(Typo.headline).foregroundStyle(Palette.ink)
                        Text(line).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.rule)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
