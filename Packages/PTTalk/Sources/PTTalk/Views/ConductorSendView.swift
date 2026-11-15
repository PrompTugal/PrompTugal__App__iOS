import CryptoKit
import PhotosUI
import PTCore
import PTLanes
import SwiftUI
import UIKit

// The picture parts are ported from VoiceDebrief `UI/PictureSheet.swift` (Apache 2.0,
// github.com/VoiceDebrief/VoiceDebrief__App__iOS): paste a screenshot from the clipboard or choose one in Photos.

/// See something on the site, write a line, paste a screenshot, send: the conductor picks it up.
struct ConductorSendView: View {
    @State private var lanes = TalkLanes.shared
    @State private var history = TalkHistory.shared
    @State private var sender = TalkSender()
    @State private var text = ""
    @State private var image: UIImage?
    @State private var nothingToPaste = false
    @State private var lastMessages: [Data] = []
    @State private var lastRecord: TalkHistory.Record?
    @Environment(\.talkSigningKey) private var signingKey

    var body: some View {
        Form {
            if lanes.conductor == nil {
                NoLaneSection()
            }
            Section("What you saw") {
                TextField("A line for the conductor", text: $text, axis: .vertical)
                    .lineLimit(2...8)
                    .accessibilityIdentifier("pt.talk.conductor.text")
            }
            Section {
                if let image {
                    PicturePreview(image: image) { self.image = nil }
                }
                PictureButtons(image: $image, nothingToPaste: $nothingToPaste)
            } header: {
                Text("Screenshot or photo")
            }
            Section {
                SendStatusView(state: sender.state, recipient: "the conductor", signed: signingKey?() != nil,
                               onTryNow: { sender.tryNow() }, onRetry: { Task { await resend() } })
            }
            let sent = history.records(.conductor)
            if !sent.isEmpty {
                Section("Sent from this device") {
                    ForEach(sent.prefix(20)) { RecordRow(record: $0) }
                }
            }
        }
        .navigationTitle("To the conductor")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") { Task { await send() } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(lanes.conductor == nil || sender.state.isBusy || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil))
                    .accessibilityIdentifier("pt.talk.conductor.send")
            }
        }
        .alert("There is no picture on the clipboard", isPresented: $nothingToPaste) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Take a screenshot, tap its preview, then Copy (or Share, Copy), and paste here.")
        }
        .onChange(of: sender.state) { _, state in
            if case .sent = state {
                text = ""
                image = nil
            }
        }
    }

    private func send() async {
        guard let lane = lanes.conductor else { return }
        var attachments: [TalkWire.Attachment] = []
        if let image, let jpeg = MediaPrep.jpeg(image) {
            attachments.append(.init(kind: .image, name: "screenshot.jpg", data: jpeg))
        }
        let item = TalkWire.itemId(purpose: .conductor, town: nil)
        do {
            lastMessages = try TalkWire.messages(item: item, purpose: .conductor, to: "conductor", text: text,
                                                 attachments: attachments, app: TalkApp.line,
                                                 signer: signingKey?().map(TalkWire.Signer.init(key:)))
        } catch {
            sender.reset()
            return
        }
        lastRecord = TalkHistory.Record(id: item, purpose: .conductor, town: nil, text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                        files: attachments.map(\.name), status: .sent, at: .now)
        await deliver(to: lane)
    }

    private func resend() async {
        guard let lane = lanes.conductor, !lastMessages.isEmpty else { return }
        await deliver(to: lane)
    }

    private func deliver(to lane: SealedLane) async {
        let ok = await sender.send(lastMessages, to: lane)
        if var record = lastRecord {
            record.status = ok ? .sent : .failed
            record.at = .now
            history.add(record)
            if ok { lastRecord = nil; lastMessages = [] }
        }
    }
}

struct NoLaneSection: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Space.s) {
                Label("No conductor lane yet", systemImage: "exclamationmark.circle").font(Typo.headline).foregroundStyle(Palette.amber)
                Text("Paste the conductor's lane link (it starts sgi1.) in Lanes. Nothing is built into the app.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                NavigationLink("Open Lanes") { LaneSettingsView() }
            }
        }
    }
}

struct PicturePreview: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: Space.s) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 360)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.rule, lineWidth: 0.5))
            Button(role: .destructive, action: onRemove) { Label("Remove", systemImage: "xmark.circle") }
                .font(.footnote)
        }
    }
}

/// "Paste screenshot" (from the clipboard) and "Choose photo" (from Photos), side by side.
struct PictureButtons: View {
    @Binding var image: UIImage?
    @Binding var nothingToPaste: Bool
    @State private var item: PhotosPickerItem?

    var body: some View {
        HStack(spacing: Space.m) {
            Button {
                if let pasted = UIPasteboard.general.image { image = pasted } else { nothingToPaste = true }
            } label: {
                Label("Paste screenshot", systemImage: "doc.on.clipboard")
            }
            .accessibilityIdentifier("pt.talk.paste")
            PhotosPicker(selection: $item, matching: .images) {
                Label("Choose photo", systemImage: "photo")
            }
        }
        .buttonStyle(.bordered)
        .font(.footnote)
        .onChange(of: item) { _, chosen in
            guard let chosen else { return }
            Task {
                if let data = try? await chosen.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                    image = picked
                }
                item = nil
            }
        }
    }
}

struct RecordRow: View {
    let record: TalkHistory.Record

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                switch record.status {
                case .sent: Label("Sent", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.green)
                case .failed: Label("Not sent", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Palette.red)
                case .kept: Label("Kept here", systemImage: "tray").foregroundStyle(Palette.muted)
                }
                Spacer()
                Text(record.at, format: .dateTime.day().month().hour().minute()).foregroundStyle(Palette.muted)
            }
            .font(.caption)
            if let town = record.town, let name = TalkTowns.name(town) {
                Text(name).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
            }
            if !record.text.isEmpty { Text(record.text).font(.subheadline).foregroundStyle(Palette.ink).lineLimit(3) }
            if !record.files.isEmpty {
                Text(record.files.joined(separator: ", ")).font(.caption.monospaced()).foregroundStyle(Palette.muted)
            }
        }
    }
}
