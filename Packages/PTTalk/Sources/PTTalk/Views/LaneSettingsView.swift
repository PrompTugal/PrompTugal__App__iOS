import PTCore
import PTLanes
import PTLocal
import SwiftUI
import UIKit

/// Where this device sends: the conductor's lane, and any town agent's. Pasted here; nothing is built in.
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

            Section {
                ForEach(PlaceDirectory.towns.sorted { $0.name < $1.name }) { town in
                    AgentLaneRow(town: town)
                }
            } header: {
                Text("Town agents' lanes")
            } footer: {
                Text("No town agent has published a lane yet. When one does, paste its link here and the conversation sends to it.")
            }
        }
        .navigationTitle("Lanes")
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

struct AgentLaneRow: View {
    let town: PlaceInfo
    @State private var lanes = TalkLanes.shared
    @State private var text = ""
    @State private var open = false
    @State private var problem = false

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            LaneSummary(lane: lanes.agent(town.id))
            TextField("sgi1.…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.caption.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            HStack {
                Button("Paste") { text = UIPasteboard.general.string ?? "" }
                Spacer()
                Button("Save") { problem = !lanes.setAgent(town.id, link: text) }
            }
            .buttonStyle(.borderless)
            if problem { Text("That is not a lane link.").font(.footnote).foregroundStyle(Palette.red) }
        } label: {
            HStack {
                Text(town.name)
                Spacer()
                Text(lanes.agent(town.id) == nil ? "No lane yet" : "Lane").font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .onAppear { text = lanes.agentLinks[town.id] ?? "" }
    }
}
