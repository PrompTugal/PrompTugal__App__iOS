import PTAsk
import PTLanes
import SwiftUI

/// Debug → Collaboration and AI: which secrets exist (never values), the lanes log, the last Ask requests.
/// For design's Debug screen: `NavigationLink("Collaboration and AI") { CollabDebugPanel() }`.
struct CollabDebugPanel: View {
    var keys: AIKeyStore = .shared
    var lanes: LanesStore = .shared

    var body: some View {
        List {
            Section("Keys (presence only)") {
                let rows = CollabDebugPanel.keyRows(keys: keys, lanes: lanes)
                ForEach(rows.indices, id: \.self) { index in
                    LabeledContent(rows[index].0, value: rows[index].1)
                }
            }
            Section("Hooks") {
                LabeledContent("Vault", value: CollabHooks.vault == nil ? "not wired" : (CollabHooks.vault!.isOpen ? "open" : "locked"))
                LabeledContent("My picks", value: "\(CollabHooks.myPickIds().count)")
                LabeledContent("Who I am", value: CollabHooks.me()?.id ?? "not chosen")
                LabeledContent("Current page", value: CollabHooks.currentPage?.title ?? "none")
                LabeledContent("Day planner", value: CollabHooks.dayPlan == nil ? "not wired" : "wired")
            }
            Section("Ask requests") {
                AskRequestsDebugRows()
            }
            Section("Lanes log") {
                if lanes.log.events.isEmpty { Text("No lane traffic yet.").foregroundStyle(.secondary) }
                ForEach(lanes.log.events.prefix(50)) { LaneEventRow(event: $0) }
            }
        }
        .navigationTitle("Collaboration and AI")
    }

    /// For the Keys panel (contracts §8): name and where it is, never a value.
    static func keyRows(keys: AIKeyStore, lanes: LanesStore) -> [(String, String)] {
        [("OpenRouter key", keys.hasKey ? "present · Keychain, this device\(keys.savedToVaultAt == nil ? "" : " · copy in vault")" : "absent"),
         ("Lane inbox key (RSA-4096)", LaneIdentity.exists ? "present · Keychain, this device" : "absent"),
         ("Lane enumeration key", lanes.hasEnumKey ? "present · Keychain, this device" : "absent"),
         ("Account inbox key", !lanes.hasWebsiteInbox ? "not open" : "in memory, from the master vault"),
         ("Lanes I can write to", "\(lanes.laneCount) (tokens are write-only)")]
    }
}
