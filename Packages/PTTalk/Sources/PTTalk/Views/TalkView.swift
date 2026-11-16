import CryptoKit
import PTCore
import PTLanes
import SwiftUI

/// The row in More. Until the conductor's lane link is on this device it only offers to connect (paste or scan the
/// link); the composers appear once a lane is set. The lane link is public by design; who may instruct the conductor
/// is decided on the receiving side, by the signature (ENVELOPE.md).
public struct TalkSection: View {
    @State private var lanes = TalkLanes.shared

    public init() {}

    public var body: some View {
        Section {
            NavigationLink {
                TalkView()
            } label: {
                Label(lanes.conductor == nil ? "Connect to the newsroom" : "Talk to the newsroom",
                      systemImage: lanes.conductor == nil ? "link" : "paperplane")
            }
            .accessibilityIdentifier("pt.more.talk")
        } footer: {
            Text(lanes.conductor == nil
                 ? "For the newsroom's team: paste the conductor's lane link to send notes and contributions."
                 : "Notes, screenshots and contributions to the conductor, sealed on this device.")
        }
    }
}

/// The lane, and once it is set, the two composers.
public struct TalkView: View {
    @State private var lanes = TalkLanes.shared

    public init() {}

    public var body: some View {
        if lanes.conductor == nil {
            LaneSettingsView()
        } else {
            TalkHome()
        }
    }
}

struct TalkHome: View {
    @State private var lanes = TalkLanes.shared
    @State private var history = TalkHistory.shared
    @State private var confirmForget = false
    @Environment(\.talkSigningKey) private var signingKey

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ConductorSendView()
                } label: {
                    TalkRow(title: "Send to the conductor", detail: "A line and a screenshot or photo", symbol: "paperplane")
                }
                .accessibilityIdentifier("pt.talk.conductor")
                NavigationLink {
                    ContributeView()
                } label: {
                    TalkRow(title: "Contribute", detail: "A photo, video or interview, as a draft for a town", symbol: "camera")
                }
                .accessibilityIdentifier("pt.talk.contribute")
            } footer: {
                Text("Sealed on this device to the conductor's key and appended to its lane: the server stores bytes it cannot read. A contribution becomes a draft; a person approves it before anything is published.")
            }
            Section {
                SigningLine(key: signingKey?())
            } footer: {
                Text("The conductor acts only on messages signed by a key registered with it. Anything unsigned, or signed by an unknown key, is read as untrusted data.")
            }
            Section {
                NavigationLink {
                    LaneSettingsView()
                } label: {
                    Label("Lane", systemImage: "point.3.connected.trianglepath.dotted")
                }
                Button(role: .destructive) {
                    confirmForget = true
                } label: {
                    Label("Forget the lane and what was sent", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Talk to the newsroom")
        .confirmationDialog("Forget the lane and the list of what was sent?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Forget", role: .destructive) {
                lanes.forgetAll()
                history.clear()
            }
        } message: {
            Text("Nothing already sent is recalled.")
        }
    }
}

struct SigningLine: View {
    let key: P256.Signing.PrivateKey?

    init(key: P256.Signing.PrivateKey?) { self.key = key }

    var body: some View {
        if let key {
            VStack(alignment: .leading, spacing: 2) {
                Label("Signed with your key", systemImage: "signature").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                Text(TalkWire.fingerprint(of: key.publicKey)).font(.caption.monospaced()).foregroundStyle(Palette.muted)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("Unsigned", systemImage: "signature").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.amber)
                Text("Sign in with your PrompTugal.news person key to sign what you send.").font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct TalkRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Palette.blue).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Sending, retrying, sent or failed, in words.
struct SendStatusView: View {
    let state: TalkSender.State
    let recipient: String
    var signed: Bool = false
    var onTryNow: () -> Void = {}
    var onRetry: () -> Void = {}

    var body: some View {
        switch state {
        case .idle:
            Text(signed
                 ? "Signed with your key, sealed to \(recipient)'s key on this device, then appended to its lane."
                 : "Sealed to \(recipient)'s key on this device, then appended to its lane. Unsigned: read as untrusted.")
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
