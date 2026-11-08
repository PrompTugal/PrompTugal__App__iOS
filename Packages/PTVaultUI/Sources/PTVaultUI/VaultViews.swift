import SGitVault
import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif

/// The vault entry view, native on iPhone and iPad.
///
/// A three-column `NavigationSplitView` (vaults → files → file). On iPhone it collapses to a stack;
/// on iPad all three columns show. The first audience is the team: importing a team vault key is
/// the first thing on the unlock screen, then Face ID for keys already on this device.
public struct VaultHomeView: View {
    @State private var session = VaultSession.shared
    @State private var selectedVault: String?
    @State private var selectedFile: String?
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var triedFaceID = false

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            VaultSidebar(session: session, selection: $selectedVault)
        } content: {
            if let id = selectedVault, let entry = session.vaults.first(where: { $0.vaultId == id }) {
                VaultFilesView(entry: entry, selection: $selectedFile)
            } else {
                ContentUnavailableView("No vault selected", systemImage: "lock.shield",
                                       description: Text("Open a vault with your team key or Face ID."))
            }
        } detail: {
            if let id = selectedVault, let path = selectedFile,
               let entry = session.vaults.first(where: { $0.vaultId == id }) {
                VaultFileView(vault: entry.vault, path: path)
            } else {
                ContentUnavailableView("No file selected", systemImage: "doc.text")
            }
        }
        .onChange(of: selectedVault) { selectedFile = nil }
        // A vault that opens is selected at once (the reader vault first), so the files show without a tap.
        .onChange(of: session.vaults.map(\.vaultId)) {
            if selectedVault == nil || !session.vaults.contains(where: { $0.vaultId == selectedVault }) {
                selectedVault = session.reader?.vaultId ?? session.vaults.first?.vaultId
            }
        }
        // Keys already on this device: one Face ID prompt when the screen opens, no tap needed.
        .task {
            guard !triedFaceID, session.isLocked, session.hasStoredKeys else { return }
            triedFaceID = true
            try? await session.unlockStoredKeys()
        }
    }
}

// MARK: Sidebar: unlock and the open vaults

struct VaultSidebar: View {
    let session: VaultSession
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            if !session.vaults.isEmpty {
                Section("Open vaults") {
                    ForEach(session.vaults) { entry in
                        VaultRow(entry: entry).tag(entry.vaultId)
                    }
                }
            }
            Section {
                VaultUnlockPanel(session: session)
            } header: {
                Text(session.vaults.isEmpty ? "Open a vault" : "Add a vault")
            }
        }
        .navigationTitle("Vaults")
        .refreshable { await session.pullAll() }
        .toolbar {
            if !session.vaults.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Lock", systemImage: "lock") {
                        selection = nil
                        session.lock()
                    }
                }
            }
        }
    }
}

struct VaultRow: View {
    let entry: VaultSession.OpenVault

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.canWrite ? "lock.open" : "eye")
                    .foregroundStyle(.secondary)
                Text(entry.label).font(.headline)
                Spacer()
                stateBadge
            }
            Text("vault \(entry.vaultId) · \(entry.fileCount) files")
                .font(.caption).foregroundStyle(.secondary).monospaced()
            if let head = entry.head {
                Text(head.message).font(.caption).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var stateBadge: some View {
        switch entry.state {
        case .pulling: ProgressView().controlSize(.small)
        case .ready: Image(systemName: "checkmark.circle").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
        case .idle: EmptyView()
        }
    }
}

/// Paste, scan, Face ID, passkey, recovery code. Team keys first.
struct VaultUnlockPanel: View {
    let session: VaultSession
    @State private var keyText = ""
    @State private var label = ""
    @State private var recoveryCode = ""
    @State private var showScanner = false
    @State private var showRecovery = false
    @State private var working = false
    @State private var message: String?
    @State private var isMine = false
    /// The key came from the clipboard: after a successful import, offer to clear it (S7).
    @State private var pastedFromClipboard = false
    @State private var offerClearClipboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.hasStoredKeys && session.vaults.isEmpty {
                Button {
                    run { try await session.unlockStoredKeys() }
                } label: {
                    Label("Open with Face ID", systemImage: "faceid").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Team or read key").font(.subheadline.weight(.semibold))
            // S6: the key is never shown on screen or in the app switcher.
            SecureField("sgit_private_vault_…:<vault id>", text: $keyText)
                .font(.callout.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
                .privacySensitive()
            TextField("Name (optional), e.g. Team keyring", text: $label)
                .font(.callout)
            Toggle("This is my own vault", isOn: $isMine)
                .font(.callout)
            HStack {
                Button {
                    let text = keyText
                    let mine = isMine
                    let name = label.isEmpty ? (mine ? "My vault" : "Teammate vault") : label
                    let fromClipboard = pastedFromClipboard
                    run {
                        try await session.importKey(text, label: name, mine: mine)
                        keyText = ""
                        label = ""
                        isMine = false
                        pastedFromClipboard = false
                        if fromClipboard { offerClearClipboard = true }
                    }
                } label: {
                    Label("Import", systemImage: "key")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!VaultUnlock.looksLikeKey(keyText) || working)

                #if canImport(UIKit)
                Button {
                    if let pasted = UIPasteboard.general.string {
                        keyText = VaultUnlock.keyText(fromScanned: pasted)
                        pastedFromClipboard = true
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                #endif

                if VaultQRScanner.isAvailable {
                    Button { showScanner = true } label: { Label("Scan", systemImage: "qrcode.viewfinder") }
                        .buttonStyle(.bordered)
                }
            }
            .labelStyle(.titleAndIcon)

            if VaultConfig.passkeyPRFEnabled {
                Button {
                    run { try await session.unlockWithPasskey() }
                } label: {
                    Label("Open with passkey (promptugal.news)", systemImage: "person.badge.key")
                }
                .buttonStyle(.bordered)
            }

            DisclosureGroup("Recovery code", isExpanded: $showRecovery) {
                TextField("ABCD-EFGH-…", text: $recoveryCode)
                    .font(.callout.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .privacySensitive()
                Button("Open with recovery code") {
                    let code = recoveryCode
                    run {
                        try await session.unlockWithRecoveryCode(code)
                        recoveryCode = ""
                    }
                }
                .disabled(VaultDoor.recoveryBytes(recoveryCode) == nil || working)
            }
            .font(.subheadline)

            if working { ProgressView("Deriving keys and pulling…") }
            if let message {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
            Text(session.protectionSummary)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        #if canImport(UIKit)
        .alert("Clear the key from the clipboard?", isPresented: $offerClearClipboard) {
            Button("Clear", role: .destructive) { UIPasteboard.general.items = [] }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The vault is open. Other apps can read the clipboard, so clearing it is safer.")
        }
        #endif
        .sheet(isPresented: $showScanner) {
            VaultQRScanner { text in
                keyText = VaultUnlock.keyText(fromScanned: text)
                showScanner = false
            }
            .ignoresSafeArea()
        }
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        working = true
        message = nil
        Task { @MainActor in
            defer { working = false }
            do { try await work() } catch { message = session.userMessage(for: error, context: "unlock panel") }
        }
    }
}

// MARK: Files and a file

extension VaultTreeNode {
    var outlineChildren: [VaultTreeNode]? { isFolder ? children : nil }
}

struct VaultFilesView: View {
    let entry: VaultSession.OpenVault
    @Binding var selection: String?
    @State private var root: VaultTreeNode?
    @State private var error: String?

    var body: some View {
        List(selection: $selection) {
            if case .failed(let text) = entry.state {
                Section {
                    Label(text, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    if let keyId = entry.untrustedSigner {
                        // S1: a new signer is never trusted silently. The person decides.
                        Text("Signed by \(keyId). Trust it only if you know this key belongs to someone who should write to this vault.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Trust this signer") {
                            Task { await VaultSession.shared.trustSigner(keyId, in: entry.vaultId) }
                        }
                    }
                }
            }
            Section {
                if VaultSession.shared.reader?.vaultId == entry.vaultId {
                    Label("My vault", systemImage: "person.crop.circle.badge.checkmark")
                } else {
                    // S5: a vault becomes "mine" only by this explicit choice (or the passkey account).
                    Button("Make this my vault") { VaultSession.shared.chooseMyVault(entry.vaultId) }
                }
            }
            if let head = entry.head {
                Section("Head") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(head.message)
                        Text("\(String(head.commitId.suffix(12))) · \(head.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                        Label(head.signature.isVerified ? "Signature verified" : "Signature not verified",
                              systemImage: head.signature.isVerified ? "checkmark.seal" : "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(head.signature.isVerified ? .green : .orange)
                    }
                }
            }
            Section("Files") {
                if let root {
                    OutlineGroup(root.children, children: \.outlineChildren) { node in
                        HStack {
                            Label(node.name, systemImage: node.isFolder ? "folder" : "doc")
                            Spacer()
                            Text(node.size.vaultByteString).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(node.path)
                    }
                } else if let error {
                    Text(error).foregroundStyle(.orange)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle(entry.label)
        .task(id: entry.head?.commitId) {
            do { root = try await entry.vault.tree() } catch {
                self.error = VaultSession.shared.userMessage(for: error, context: "tree \(entry.vaultId)")
            }
        }
        .refreshable { await VaultSession.shared.pull(entry.vaultId) }
    }
}

struct VaultFileView: View {
    let vault: SGitVault
    let path: String
    @State private var text: String?
    @State private var size = 0
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let text {
                Text(text)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else if let error {
                Text(error).foregroundStyle(.orange).padding()
            } else {
                ProgressView().padding()
            }
        }
        .navigationTitle(path.split(separator: "/").last.map(String.init) ?? path)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: path) {
            text = nil
            error = nil
            do {
                let data = try await vault.read(path)
                size = data.count
                text = String(data: data, encoding: .utf8) ?? "Binary file, \(data.count.vaultByteString)"
            } catch {
                self.error = VaultSession.shared.userMessage(for: error, context: "read")
            }
        }
    }
}

// MARK: QR scanner

/// Reads a vault key from a QR code with VisionKit (needs NSCameraUsageDescription).
struct VaultQRScanner: UIViewControllerRepresentable {
    let onText: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onText: onText) }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onText: (String) -> Void
        init(onText: @escaping (String) -> Void) { self.onText = onText }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in items {
                if case .barcode(let code) = item, let text = code.payloadStringValue, VaultUnlock.looksLikeKey(text) {
                    scanner.stopScanning()
                    onText(text)
                    return
                }
            }
        }
    }
}

