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

/// A horizontal bar showing a duration against the slowest in view.
struct TimingBar: View {
    let value: Double
    let maxValue: Double
    var color: Color = Palette.blue

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.rule.opacity(0.4))
                Capsule().fill(color)
                    .frame(width: max(2, geo.size.width * CGFloat(min(value / max(maxValue, 0.001), 1))))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// A chip that toggles a filter.
struct FilterChip: View {
    let title: String
    let isOn: Bool
    var color: Color = Palette.red
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isOn ? Color.white : color)
                .background(isOn ? color : color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
