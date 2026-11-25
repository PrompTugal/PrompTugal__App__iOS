import CryptoKit
import Foundation
import PTCore
import SwiftUI

// Talk to us from the app (Dinis, 15 Nov ~23:30, relayed by conductor@): a signed-in person comments on any place or
// story; the comment is signed with their person key and sent to the conductor; the conductor's reply is sealed to the
// person (ws-ecies-1) and opened on the device. The transport (seal to the conductor's key, append to its lane, read
// the reply lane) is conductor.a.ios@'s PTTalk; the app wires it in with `.placesTalk(...)`. Without it the button
// says comments are not connected in this build: nothing pretends to send.

/// What PTPlaces needs from a transport. PTTalk's TalkTransport conforms in the app.
public protocol PlacesTalk: Sendable {
    func send(_ payload: Data, signedBy key: P256.Signing.PrivateKey) async throws
    /// The person's reply envelopes, newest last, as received (JSON of a ws-ecies-1 envelope each).
    func replies(for person: String) async throws -> [Data]
}

private struct PlacesTalkKey: EnvironmentKey {
    static let defaultValue: (any PlacesTalk)? = nil
}

extension EnvironmentValues {
    public var placesTalk: (any PlacesTalk)? {
        get { self[PlacesTalkKey.self] }
        set { self[PlacesTalkKey.self] = newValue }
    }
}

extension View {
    public func placesTalk(_ talk: (any PlacesTalk)?) -> some View { environment(\.placesTalk, talk) }
}

private struct PlacesCommentsKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False hides every Comment button and the Sign in badge (the App Store build, until comments work end to end).
    public var placesComments: Bool {
        get { self[PlacesCommentsKey.self] }
        set { self[PlacesCommentsKey.self] = newValue }
    }
}

extension View {
    public func placesComments(_ shown: Bool) -> some View { environment(\.placesComments, shown) }
}

/// What a comment is about: a place, or one story or map entry on it.
public struct CommentSubject: Hashable, Sendable, Identifiable {
    public var place: String
    public var title: String
    /// The story's source URL or the map entry's name; empty for the place itself.
    public var item: String
    public var page: String

    public var id: String { place + "|" + item }

    public init(place: String, title: String, item: String = "", page: String = "") {
        self.place = place; self.title = title; self.item = item; self.page = page
    }
}

/// The message as sent (plaintext before the transport seals it), and how it is signed.
public enum CommentMessage {
    public static let kind = "promptugal/comment/v1"

    /// The signed text: one line per field, in this order, so any reader can rebuild and verify it.
    public static func signedText(kind: String, person: String, at: String, place: String, item: String, text: String) -> String {
        [kind, person, at, place, item, text].joined(separator: "\n")
    }

    public static func payload(subject: CommentSubject, text: String, feedback: String?, key: PersonKey, at: Date = .now) throws -> Data {
        let stamp = ISO8601DateFormatter().string(from: at)
        let body = feedback.map { "[\($0)] " + text } ?? text
        let signed = signedText(kind: kind, person: key.person, at: stamp, place: subject.place, item: subject.item, text: body)
        let object: [String: Any] = [
            "kind": kind, "person": key.person, "key": key.fingerprint, "signing_key": key.signingFingerprint,
            "at": stamp, "place": subject.place, "item": subject.item, "title": subject.title, "page": subject.page,
            "text": body, "feedback": feedback ?? "", "from": "ios", "signature": try key.sign(signed),
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

/// A reply, opened: {text, place?, item?, by?, at?}.
public struct CommentReply: Identifiable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var place: String
    public var item: String
    public var by: String
    public var at: String

    static func open(_ data: Data, with key: PersonKey) -> CommentReply? {
        guard let envelope = try? JSONDecoder().decode(SealedEnvelope.self, from: data),
              let plain = try? key.open(envelope),
              let object = try? JSONSerialization.jsonObject(with: plain) as? [String: Any] else { return nil }
        let text = object["text"] as? String ?? object["reply"] as? String ?? ""
        guard !text.isEmpty else { return nil }
        return CommentReply(id: envelope.iv, text: text, place: object["place"] as? String ?? "",
                            item: object["item"] as? String ?? "", by: object["by"] as? String ?? envelope.by ?? "",
                            at: object["at"] as? String ?? envelope.at ?? "")
    }
}

/// The Comment button: opens the composer for a place or a story.
struct CommentButton: View {
    let subject: CommentSubject
    let accent: Color
    var compact = false
    @State private var composing = false
    @Environment(\.placesComments) private var shown

    var body: some View {
        if shown { button }
    }

    private var button: some View {
        Button { composing = true } label: {
            if compact {
                Image(systemName: "text.bubble")
            } else {
                Label(String(localized: "Comment"), systemImage: "text.bubble")
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(accent)
        .buttonStyle(.plain)
        .sheet(isPresented: $composing) { CommentComposer(subject: subject, accent: accent) }
        .accessibilityLabel(String(localized: "Comment on \(subject.title)"))
        .accessibilityIdentifier("places.comment")
    }
}

/// Thumbs up or down: anonymous (no person, no key), an unsigned vote on the website's observability lane, and
/// remembered on the device so the button stays lit. Written feedback goes in a signed comment instead.
struct ThumbsBar: View {
    let subject: CommentSubject
    let accent: Color
    @AppStorage("places.thumbs") private var thumbs = ""
    @Environment(\.placesComments) private var shown

    private var current: String? {
        thumbs.split(separator: ";").first { $0.hasPrefix(subject.id + "=") }.map { String($0.split(separator: "=").last ?? "") }
    }

    var body: some View {
        // Hidden with comments (App Store build): a vote leaves the device, and the privacy answer is Data Not Collected.
        if shown { bar }
    }

    private var bar: some View {
        HStack(spacing: Space.m) {
            thumb("up", "hand.thumbsup")
            thumb("down", "hand.thumbsdown")
        }
    }

    private func thumb(_ value: String, _ symbol: String) -> some View {
        let on = current == value
        return Button {
            set(on ? nil : value)
        } label: {
            Image(systemName: on ? symbol + ".fill" : symbol)
        }
        .buttonStyle(.plain)
        .foregroundStyle(on ? accent : Palette.muted)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(value == "up" ? String(localized: "Useful") : String(localized: "Not useful"))
    }

    /// The path voted on: the place's page, with the story's source after a # when it is a story.
    private var path: String {
        let page = URL(string: subject.page)?.path ?? "/"
        return subject.item.isEmpty ? page : page + "#" + subject.item
    }

    private func set(_ value: String?) {
        var entries = thumbs.split(separator: ";").map(String.init).filter { !$0.hasPrefix(subject.id + "=") }
        if let value { entries.append(subject.id + "=" + value) }
        thumbs = entries.joined(separator: ";")
        guard let value else { return }
        let path = self.path
        Task.detached { await AnonymousVote.send(vote: value == "up" ? 1 : -1, on: path) }
    }
}

/// Write a comment, see the conductor's replies on this subject.
struct CommentComposer: View {
    let subject: CommentSubject
    let accent: Color
    @Environment(\.placesTalk) private var talk
    @Environment(\.dismiss) private var dismiss
    @State private var session = PersonSession.shared
    @State private var text = ""
    @State private var sending = false
    @State private var sent: [String] = []
    @State private var replies: [CommentReply] = []
    @State private var problem: String?
    @State private var signingIn = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(subject.title).font(.headline)
                    if !subject.item.isEmpty { Text(subject.item).font(.caption).foregroundStyle(Palette.muted).lineLimit(2) }
                }
                if session.key == nil {
                    Section {
                        Text(String(localized: "Sign in with your person key to comment. Your comment is signed with it, and the agents' replies are sealed to you."))
                            .font(.subheadline)
                        Button(String(localized: "Sign in")) { signingIn = true }
                    }
                } else if talk == nil {
                    Section {
                        Label(String(localized: "Comments are not connected in this build yet."), systemImage: "bolt.horizontal.circle")
                            .foregroundStyle(Palette.muted)
                    }
                } else {
                    Section {
                        TextField(String(localized: "What should the agents know or fix?"), text: $text, axis: .vertical)
                            .lineLimit(3...10)
                        Button {
                            Task { await send() }
                        } label: {
                            if sending { ProgressView() } else { Label(String(localized: "Send, signed as \(session.person ?? "")"), systemImage: "paperplane.fill") }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                    } footer: {
                        Text(String(localized: "Signed with your person key and sent to the conductor. Agents draft the answer; it comes back here, opened only on this device."))
                    }
                }
                if !sent.isEmpty {
                    Section(String(localized: "Sent")) {
                        ForEach(sent, id: \.self) { Text($0).font(.subheadline) }
                    }
                }
                if !replies.isEmpty {
                    Section(String(localized: "Replies")) {
                        ForEach(replies) { reply in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reply.text).font(.subheadline)
                                Text([reply.by, PlaceDates.ago(reply.at)].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                if let problem {
                    Section { Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(Palette.red) }
                }
            }
            .navigationTitle(String(localized: "Comment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Close")) { dismiss() } }
                if talk != nil, session.key != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button { Task { await loadReplies() } } label: { Image(systemName: "arrow.clockwise") }
                            .accessibilityLabel(String(localized: "Check for replies"))
                    }
                }
            }
            .sheet(isPresented: $signingIn) { SignInView() }
            .task { await loadReplies() }
            .refreshable { await loadReplies() }
        }
        .tint(accent)
    }

    private func send() async {
        guard let talk, let key = session.key else { return }
        sending = true
        problem = nil
        do {
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = try CommentMessage.payload(subject: subject, text: body, feedback: nil, key: key)
            try await talk.send(payload, signedBy: try key.signingKey())
            _ = PlacesCredit.charge("contribution", subject.id, nil, subject.title)
            sent.append(body)
            text = ""
        } catch {
            problem = String(localized: "Not sent: \(error.localizedDescription)")
        }
        sending = false
    }

    private func loadReplies() async {
        guard let talk, let key = session.key else { return }
        do {
            let all = try await talk.replies(for: key.person).compactMap { CommentReply.open($0, with: key) }
            replies = all.filter { $0.place.isEmpty || $0.place == subject.place }
        } catch {
            problem = String(localized: "Replies could not be read: \(error.localizedDescription)")
        }
    }
}
