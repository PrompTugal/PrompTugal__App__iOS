import PTCore
import PTLanes
import SwiftUI
import UIKit

/// Where this device sends: the conductor's lane. Pasted here; nothing is built in.
struct LaneSettingsView: View {
    @State private var lanes = TalkLanes.shared
    @State private var conductorText = ""
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                LaneSummary(lane: lanes.conductor)
                TextField("sgi1.…", text: $conductorText, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.caption.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("pt.talk.lanes.conductor")
                HStack {
                    Button("Paste") { conductorText = UIPasteboard.general.string ?? "" }
                    Spacer()
                    Button("Save") { save() }.disabled(conductorText == lanes.conductorLink)
                }
                .buttonStyle(.borderless)
                if let problem { Text(problem).font(.footnote).foregroundStyle(Palette.red) }
            } header: {
                Text("The conductor's lane")
            } footer: {
                Text("The link the conductor gives you, starting sgi1. A lane link is public by design: a vault id, a token that can only write, and a public key. Only the holder of the private key can read what is sent. Lanes use dev.send.sgraph.ai only.")
            }

        }
        .navigationTitle("The conductor's lane")
        .onAppear { conductorText = lanes.conductorLink }
    }

    private func save() {
        if lanes.setConductor(conductorText) {
            problem = nil
            conductorText = lanes.conductorLink
        } else {
            problem = "That is not a lane link: it should hold sgi1.<vault>.<token>.<key>."
        }
    }
}

struct LaneSummary: View {
    let lane: SealedLane?

    var body: some View {
        if let lane {
            VStack(alignment: .leading, spacing: 2) {
                Label("Lane set", systemImage: "lock.shield").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                Text("Vault \(lane.vault) · token \(lane.tokenHint) · key \(lane.fingerprint)")
                    .font(.caption.monospaced()).foregroundStyle(Palette.muted)
            }
        } else {
            Label("No lane yet", systemImage: "tray").font(.subheadline).foregroundStyle(Palette.amber)
        }
    }
}
