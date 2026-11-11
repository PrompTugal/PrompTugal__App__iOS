import SwiftUI

enum RiskMandateContent {
    static let title = "RiskMandate"
    static let line = "Agent Behaviour Policies, demos and explanations."
    static let abpURL = URL(string: "https://riskmandate.ai/abp.html")!
}

/// The small settings screen behind the command centre's gear button: the command centre's
/// address (per device), a reload, and the on-device model Workbench.
struct SettingsView: View {
    @Binding var address: String
    let reload: () -> Void
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss

    private var draftURL: URL? { CommandCentreSettings.validURL(draft) }
    private var isDefault: Bool { address == CommandCentreSettings.defaultAddress }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://…", text: $draft, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                    if !draft.isEmpty && draftURL == nil {
                        Text("Enter an https:// address.").foregroundStyle(.red)
                    }
                    Button("Open this address") {
                        if let url = draftURL { address = url.absoluteString }
                        dismiss()
                    }
                    .disabled(draftURL == nil || draftURL?.absoluteString == address)
                    Button("Use the default (Silvio's X-Ray)") {
                        address = CommandCentreSettings.defaultAddress
                        draft = address
                    }
                    .disabled(isDefault)
                } header: {
                    Text("Command centre address")
                } footer: {
                    Text("Point it at your own page, for example https://web-summit.sgit.ai/people/<id>/app/index.html#xray. Saved on this device only.")
                }

                Section {
                    Button {
                        reload()
                        dismiss()
                    } label: {
                        Label("Reload the command centre", systemImage: "arrow.clockwise")
                    }
                }

                Section("On this device") {
                    NavigationLink {
                        WorkbenchView()
                    } label: {
                        Label("Workbench: an AI model on this device", systemImage: "cpu")
                    }
                }

                Section {
                    Link("Read about Agent Behaviour Policies", destination: RiskMandateContent.abpURL)
                } footer: {
                    Text(RiskMandateContent.line)
                }
            }
            .navigationTitle(RiskMandateContent.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { draft = address }
        }
    }
}

#Preview {
    SettingsView(address: .constant(CommandCentreSettings.defaultAddress), reload: {})
}
