import SwiftUI
import PTCore

/// The Bridge panel for Debug (contracts §8): every message between pages and the app, newest first.
/// The design session can embed it in its Debug screen as is.
public struct BridgeLogView: View {
    public init() {}

    @Environment(BridgeLog.self) private var log
    @Environment(AppBridge.self) private var bridge

    public var body: some View {
        List {
            Section {
                LabeledContent("Handler", value: "\(AppBridge.handlerName), own content world")
                LabeledContent("Allowed origins", value: AppBridge.allowedHosts.sorted().joined(separator: ", "))
                LabeledContent("Ops", value: AppBridge.ops.joined(separator: ", "))
                if let last = bridge.lastScheduleSync {
                    LabeledContent("Schedule synced", value: Lisbon.timeLabel(last))
                }
            } footer: {
                Text("Op names, hosts, counts and outcomes only. No page data, no keys.")
            }
            Section("Messages (\(log.entries.count))") {
                ForEach(log.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.op).font(.subheadline.monospaced().weight(.semibold))
                            Spacer()
                            Text(entry.outcome.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(entry.outcome == .ok ? .green : entry.outcome == .refused ? .orange : .red)
                        }
                        Text("\(entry.direction.rawValue) · \(entry.host) · \(entry.at.formatted(date: .omitted, time: .standard))\(entry.durationMs.map { String(format: " · %.0f ms", $0) } ?? "")")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        if !entry.detail.isEmpty { Text(entry.detail).font(.caption) }
                    }
                }
            }
        }
        .navigationTitle("Bridge")
        .toolbar { Button("Clear") { log.clear() } }
    }
}
