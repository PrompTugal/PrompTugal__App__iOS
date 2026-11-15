import PTCore
import PTLanes
import PTLocal
import SwiftUI

/// The one row the public sees in More: "Owner", locked. Everything behind it is hidden until this device is
/// unlocked with the owner's passphrase (set on first use, kept as a hash in the Keychain).
public struct OwnerTalkSection: View {
    @State private var lock = OwnerLock.shared

    public init() {}

    public var body: some View {
        Section {
            NavigationLink {
                OwnerTalkView()
            } label: {
                Label(lock.isUnlocked ? "Owner: talk to the newsroom" : "Owner", systemImage: lock.isUnlocked ? "lock.open" : "lock")
            }
            .accessibilityIdentifier("pt.more.owner")
        } footer: {
            Text(lock.isSet ? "For the owner of this device only." : "For the owner of this device only: set a passphrase on first use.")
        }
    }
}

/// Behind the lock: send to the conductor, contribute, talk to a town's agent, and the lanes.
public struct OwnerTalkView: View {
    @State private var lock = OwnerLock.shared
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        Group {
            if lock.isUnlocked {
                OwnerTalkHome()
            } else {
                OwnerLockView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lock() }
        }
    }
}

struct OwnerTalkHome: View {
    @State private var lanes = TalkLanes.shared
    @State private var lock = OwnerLock.shared
    @State private var history = TalkHistory.shared
    @State private var confirmForget = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ConductorSendView()
                } label: {
                    TalkRow(title: "Send to the conductor", detail: "A line and a screenshot or photo", symbol: "paperplane",
                            lane: lanes.conductor)
                }
                .accessibilityIdentifier("pt.talk.conductor")
                NavigationLink {
                    ContributeView()
                } label: {
                    TalkRow(title: "Contribute", detail: "A photo, video or interview, as a draft for a town", symbol: "camera",
                            lane: lanes.conductor)
                }
                .accessibilityIdentifier("pt.talk.contribute")
            } header: {
                Text("The conductor")
            } footer: {
                Text("Sealed on this device to the conductor's key and appended to its lane: the server stores bytes it cannot read. A contribution becomes a draft; a person approves it before anything is published.")
            }

            Section {
                ForEach(PlaceDirectory.towns.sorted { $0.name < $1.name }) { town in
                    NavigationLink {
                        TownAgentView(town: town)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(town.name).font(Typo.headline).foregroundStyle(Palette.ink)
                                Text(town.agent).font(.caption.monospaced()).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            if lanes.agent(town.id) != nil {
                                Label("Lane", systemImage: "lock.shield").font(.caption2.weight(.semibold)).foregroundStyle(Palette.green)
                            } else {
                                Text("No lane yet").font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
            } header: {
                Text("Talk to a town's agent")
            } footer: {
                Text("No town agent has a lane yet: messages stay on this device until one does. Meanwhile Apple Intelligence answers on this device from the town's published data, and says so.")
            }

            Section {
                NavigationLink {
                    LaneSettingsView()
                } label: {
                    Label("Lanes", systemImage: "point.3.connected.trianglepath.dotted")
                }
                Button {
                    lock.lock()
                } label: {
                    Label("Lock now", systemImage: "lock")
                }
                Button(role: .destructive) {
                    confirmForget = true
                } label: {
                    Label("Forget the passphrase, lanes and history", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Owner")
        .confirmationDialog("Forget everything on this device?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Forget", role: .destructive) {
                lanes.forgetAll()
                history.clear()
                lock.reset()
            }
        } message: {
            Text("The passphrase, the pasted lanes and what was sent from here. Nothing already sent is recalled.")
        }
    }
}

struct TalkRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String
    let lane: SealedLane?

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Palette.blue).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.caption).foregroundStyle(Palette.muted)
                if lane == nil {
                    Text("No lane yet: paste the conductor's link in Lanes").font(.caption2).foregroundStyle(Palette.amber)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// First use: set the passphrase. Afterwards: unlock.
struct OwnerLockView: View {
    @State private var lock = OwnerLock.shared
    @State private var passphrase = ""
    @State private var confirm = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Space.s) {
                    Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(Palette.blue)
                    Text(lock.isSet ? "Unlock" : "Set the owner's passphrase").font(Typo.title)
                    Text(lock.isSet
                         ? "Messages to the conductor and to the agents can carry instructions, so only the owner of this device sends them."
                         : "Only someone with this passphrase can send to the conductor or the agents from this device. It is never stored: the Keychain keeps a hash, on this device only.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                .padding(.vertical, Space.s)
            }
            Section {
                SecureField("Passphrase", text: $passphrase)
                    .textContentType(lock.isSet ? .password : .newPassword)
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit(go)
                    .accessibilityIdentifier("pt.owner.passphrase")
                if !lock.isSet {
                    SecureField("The same again", text: $confirm)
                        .textContentType(.newPassword)
                        .onSubmit(go)
                        .accessibilityIdentifier("pt.owner.confirm")
                }
            } footer: {
                if let error {
                    Text(error).foregroundStyle(Palette.red)
                } else if !lock.isSet {
                    Text("At least \(OwnerLock.minimumLength) characters.")
                }
            }
            Section {
                Button(lock.isSet ? "Unlock" : "Set and unlock", action: go)
                    .disabled(passphrase.isEmpty)
                    .accessibilityIdentifier("pt.owner.go")
            }
        }
        .navigationTitle("Owner")
        .onAppear { focused = true }
    }

    private func go() {
        do {
            if lock.isSet { try lock.unlock(passphrase) } else { try lock.set(passphrase, confirm: confirm) }
            error = nil
            passphrase = ""
            confirm = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Sending, retrying, sent or failed, in words.
struct SendStatusView: View {
    let state: TalkSender.State
    let recipient: String
    var onTryNow: () -> Void = {}
    var onRetry: () -> Void = {}

    var body: some View {
        switch state {
        case .idle:
            Text("Sealed to \(recipient)'s key on this device, then appended to its lane.")
                .font(.footnote).foregroundStyle(Palette.muted)
        case .sending(let done, let total):
            VStack(alignment: .leading, spacing: 6) {
                HStack { ProgressView(); Text("Sending, part \(min(done + 1, total)) of \(total)").font(.footnote) }
                ProgressView(value: Double(done), total: Double(max(total, 1)))
            }
        case .retrying(let attempt, let of, let next):
            HStack {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(Palette.amber)
                Text("Not through. Trying again \(Text(next, style: .relative)) (try \(attempt) of \(of))").font(.footnote)
                Spacer()
                Button("Try now", action: onTryNow).font(.footnote)
            }
        case .sent(let at):
            Label("Sent to \(recipient) at \(at.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(Palette.green)
        case .failed(let why):
            VStack(alignment: .leading, spacing: 8) {
                Label("Not sent: \(why)", systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(Palette.red)
                Button("Send again", action: onRetry)
            }
        }
    }
}
