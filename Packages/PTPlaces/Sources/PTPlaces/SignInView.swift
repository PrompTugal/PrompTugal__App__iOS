import Observation
import PTCore
import SwiftUI
import VisionKit

/// Who is signed in on this device, with the key proved against the public register.
@MainActor @Observable
public final class PersonSession {
    public static let shared = PersonSession()
    public static let registerURL = URL(string: "https://promptugal.news/board/person-keys.json")!

    public private(set) var key: PersonKey?
    /// Proved against the register this session (false while offline: the key still signs, the badge says so).
    public private(set) var proved = false
    public private(set) var problem: String?
    let register = RemoteFeed<PersonKeyRegister>(name: "person-keys", url: PersonSession.registerURL)

    public init() {
        key = PersonKeychain.load()
    }

    public var person: String? { key?.person }

    /// Reads a sign-in link or QR text, proves it, keeps it in the Keychain.
    public func signIn(with text: String) async -> Bool {
        problem = nil
        do {
            let candidate = try PersonKey(link: text)
            await register.load(force: true)
            guard let list = register.value else {
                problem = String(localized: "The register of keys could not be read. Try again online.")
                return false
            }
            try candidate.prove(against: list)
            try PersonKeychain.save(candidate)
            key = candidate
            proved = true
            return true
        } catch let failure as PersonKey.Failure {
            problem = Self.message(failure)
        } catch {
            problem = error.localizedDescription
        }
        return false
    }

    /// Re-proves the stored key (a key replaced on the website stops working here too).
    public func refresh() async {
        guard let key else { return }
        await register.load()
        guard let list = register.value else { return }
        do {
            try key.prove(against: list)
            proved = true
        } catch {
            proved = false
            if (error as? PersonKey.Failure) == .replaced { signOut(); problem = Self.message(.replaced) }
        }
    }

    public func signOut() {
        PersonKeychain.delete()
        key = nil
        proved = false
    }

    static func message(_ failure: PersonKey.Failure) -> String {
        switch failure {
        case .noKeyInLink: String(localized: "That is not a sign-in link. Paste the link or scan the QR code your conductor gave you.")
        case .unreadable: String(localized: "The key in that link could not be read.")
        case .wrongFingerprint: String(localized: "The key does not match its fingerprint.")
        case .notInRegister: String(localized: "This key is not in promptugal.news's register of person keys.")
        case .replaced: String(localized: "This key was replaced by a newer one. Ask your conductor for a new link.")
        }
    }
}

/// The signed-in person as a small badge, or a Sign in button.
public struct PersonBadge: View {
    @State private var session = PersonSession.shared
    @State private var showing = false
    @Environment(\.placesComments) private var shown

    public init() {}

    public var body: some View {
        if shown { badge }
    }

    private var badge: some View {
        Button { showing = true } label: {
            if let person = session.person {
                Label(person, systemImage: session.proved ? "person.badge.key.fill" : "person.badge.key")
            } else {
                Label(String(localized: "Sign in"), systemImage: "key")
            }
        }
        .font(.caption.weight(.semibold))
        .sheet(isPresented: $showing) { SignInView() }
        .task { await session.refresh() }
        .accessibilityIdentifier("places.person")
    }
}

/// Sign in with the person key: paste the link, or scan its QR code. The key stays in this device's Keychain.
public struct SignInView: View {
    @State private var session = PersonSession.shared
    @State private var text = ""
    @State private var scanning = false
    @State private var working = false
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                if let key = session.key {
                    Section {
                        LabeledContent(String(localized: "Signed in as"), value: key.person)
                        LabeledContent(String(localized: "Key"), value: key.fingerprint)
                        LabeledContent(String(localized: "Checked against the register"),
                                       value: session.proved ? String(localized: "Yes") : String(localized: "Not yet (offline?)"))
                    } footer: {
                        Text(String(localized: "Your comments are signed with this key and sealed to the conductor. Replies are sealed to you and opened only on this device."))
                    }
                    Section {
                        Button(String(localized: "Sign out"), role: .destructive) { session.signOut() }
                    }
                } else {
                    Section {
                        if DataScannerViewController.isSupported {
                            Button {
                                scanning = true
                            } label: {
                                Label(String(localized: "Scan the QR code"), systemImage: "qrcode.viewfinder")
                            }
                        }
                        PasteButton(payloadType: String.self) { strings in
                            if let first = strings.first { text = first; Task { await submit() } }
                        }
                        TextField(String(localized: "or paste the sign-in link"), text: $text, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.footnote.monospaced())
                            .lineLimit(3...6)
                        Button {
                            Task { await submit() }
                        } label: {
                            if working { ProgressView() } else { Text(String(localized: "Sign in")) }
                        }
                        .disabled(text.isEmpty || working)
                    } header: {
                        Text(String(localized: "Your person key"))
                    } footer: {
                        Text(String(localized: "Your conductor gives you a sign-in link or its QR code. The key never leaves this device: it is kept in the Keychain and checked against promptugal.news/board/person-keys.json."))
                    }
                }
                if let problem = session.problem {
                    Section { Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(Palette.red) }
                }
            }
            .navigationTitle(String(localized: "Sign in"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Done")) { dismiss() } }
            }
            .sheet(isPresented: $scanning) {
                QRScanner { found in
                    scanning = false
                    text = found
                    Task { await submit() }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func submit() async {
        working = true
        if await session.signIn(with: text) { text = "" }
        working = false
    }
}

/// VisionKit's live scanner, for QR codes only; calls back with the first payload.
struct QRScanner: UIViewControllerRepresentable {
    let found: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(found: found) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void
        var done = false
        init(found: @escaping (String) -> Void) { self.found = found }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                if case .barcode(let code) = item, let payload = code.payloadStringValue {
                    done = true
                    dataScanner.stopScanning()
                    found(payload)
                    return
                }
            }
        }
    }
}
