import PTCore
import PTLanes
import SwiftUI
import UIKit

/// Where this device sends: the conductor's lane. Pasted here; nothing is built in.
struct LaneSettingsView: View {
    @State private var lanes = TalkLanes.shared
    @State private var conductorText = ""
    @State private var problem: String?
    @State private var scanning = false

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
                    if LaneScanner.isAvailable {
                        Button { scanning = true } label: { Label("Scan QR", systemImage: "qrcode.viewfinder") }
                            .accessibilityIdentifier("pt.talk.lanes.scan")
                        Spacer()
                    }
                    Button("Paste") { conductorText = UIPasteboard.general.string ?? "" }
                    Spacer()
                    Button("Save") { save() }.disabled(conductorText == lanes.conductorLink)
                }
                .buttonStyle(.borderless)
                if let problem { Text(problem).font(.footnote).foregroundStyle(Palette.red) }
            } header: {
                Text("The conductor's lane")
            } footer: {
                Text("Scan the conductor's QR code or paste its link (it starts sgi1.). It holds a vault id, a token that can only write, and the conductor's public key; only the conductor can read what is sent. Kept in this device's Keychain. Lanes use dev.send.sgraph.ai only.")
            }

        }
        .navigationTitle("The conductor's lane")
        .onAppear { conductorText = lanes.conductorLink }
        .sheet(isPresented: $scanning) {
            NavigationStack {
                LaneScanner { link in
                    conductorText = link
                    scanning = false
                    save()
                }
                .ignoresSafeArea()
                .navigationTitle("Scan the lane's QR code")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { scanning = false } } }
            }
        }
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
