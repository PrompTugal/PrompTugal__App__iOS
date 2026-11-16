import AVKit
import CryptoKit
import PhotosUI
import PTCore
import PTLanes
import SwiftUI
import UIKit

/// A photo, a video or a recorded interview (with its transcript, made on this device), about a town, sent to the
/// conductor's lane as a draft. A person approves a draft before anything is published.
struct ContributeView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case photo, video, interview
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .photo: "Photo"
            case .video: "Video"
            case .interview: "Interview"
            }
        }
    }

    @State private var lanes = TalkLanes.shared
    @State private var history = TalkHistory.shared
    @State private var sender = TalkSender()
    @State private var recorder = InterviewRecorder()
    @AppStorage("talk.contribute.town") private var town = "loule"
    @State private var kind: Kind = .photo
    @State private var title = ""
    @State private var notes = ""
    @State private var image: UIImage?
    @State private var video: URL?
    @State private var videoBytes = 0
    @State private var preparingVideo = false
    @State private var videoItem: PhotosPickerItem?
    @State private var nothingToPaste = false
    @State private var problem: String?
    @State private var lastMessages: [Data] = []
    @State private var lastRecord: TalkHistory.Record?
    @Environment(\.talkSigningKey) private var signingKey

    var body: some View {
        Form {
            if lanes.conductor == nil { NoLaneSection() }
            Section {
                Picker("Town", selection: $town) {
                    ForEach(TalkTowns.all) { Text($0.name).tag($0.id) }
                }
                .accessibilityIdentifier("pt.talk.contribute.town")
                Picker("What", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Goes to \(TalkTowns.name(town) ?? town)'s drafts through the conductor. A person approves it before it is published.")
            }

            switch kind {
            case .photo: photoSection
            case .video: videoSection
            case .interview: interviewSection
            }

            Section("About it") {
                TextField("A title", text: $title)
                TextField("What it shows, who, where, when", text: $notes, axis: .vertical).lineLimit(2...8)
            }

            Section {
                if let problem { Text(problem).font(.footnote).foregroundStyle(Palette.red) }
                SendStatusView(state: sender.state, recipient: "the conductor", signed: signingKey?() != nil,
                               onTryNow: { sender.tryNow() }, onRetry: { Task { await resend() } })
            }

            let sent = history.records(.draft)
            if !sent.isEmpty {
                Section("Contributed from this device") {
                    ForEach(sent.prefix(20)) { RecordRow(record: $0) }
                }
            }
        }
        .navigationTitle("Contribute")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Send draft") { Task { await send() } }
                    .disabled(!canSend)
                    .accessibilityIdentifier("pt.talk.contribute.send")
            }
        }
        .alert("There is no picture on the clipboard", isPresented: $nothingToPaste) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: videoItem) { _, chosen in
            guard let chosen else { return }
            Task { await loadVideo(chosen) }
        }
        .onChange(of: sender.state) { _, state in
            if case .sent = state { clear() }
        }
    }

    // MARK: Sections

    @ViewBuilder private var photoSection: some View {
        Section("Photo") {
            if let image { PicturePreview(image: image) { self.image = nil } }
            PictureButtons(image: $image, nothingToPaste: $nothingToPaste)
        }
    }

    @ViewBuilder private var videoSection: some View {
        Section {
            if let video {
                VideoPlayer(player: AVPlayer(url: video)).frame(height: 240)
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(videoBytes), countStyle: .file)).font(.caption).foregroundStyle(Palette.muted)
                    Spacer()
                    Button(role: .destructive) { self.video = nil } label: { Label("Remove", systemImage: "xmark.circle") }.font(.footnote)
                }
            }
            if preparingVideo {
                HStack { ProgressView(); Text("Making the video smaller…").font(.footnote) }
            }
            PhotosPicker(selection: $videoItem, matching: .videos) {
                Label(video == nil ? "Choose a video" : "Choose another video", systemImage: "video")
            }
        } header: {
            Text("Video")
        } footer: {
            Text("Compressed on this device to medium quality, sent in parts of 2 MB, \(ByteCountFormatter.string(fromByteCount: Int64(TalkWire.maxFileBytes), countStyle: .file)) at most.")
        }
    }

    @ViewBuilder private var interviewSection: some View {
        Section {
            HStack(spacing: Space.m) {
                switch recorder.phase {
                case .idle, .failed:
                    Button { Task { await recorder.start(localeId: recorder.localeId) } } label: {
                        Label("Record", systemImage: "record.circle").foregroundStyle(Palette.red)
                    }
                case .recording:
                    Button { recorder.pause() } label: { Label("Pause", systemImage: "pause.circle") }
                    Button { Task { await recorder.stop(localeId: recorder.localeId) } } label: { Label("Stop", systemImage: "stop.circle") }
                case .paused:
                    Button { recorder.resume() } label: { Label("Resume", systemImage: "record.circle") }
                    Button { Task { await recorder.stop(localeId: recorder.localeId) } } label: { Label("Stop", systemImage: "stop.circle") }
                case .transcribing:
                    ProgressView()
                    Text("Transcribing on this device…").font(.footnote)
                case .done:
                    Label("Recorded", systemImage: "checkmark.circle").foregroundStyle(Palette.green)
                    Spacer()
                    Button(role: .destructive) { recorder.discard() } label: { Label("Discard", systemImage: "trash") }
                }
            }
            .buttonStyle(.borderless)
            if recorder.phase == .recording || recorder.phase == .paused {
                HStack {
                    Text(Duration.seconds(recorder.elapsed).formatted(.time(pattern: .minuteSecond))).monospacedDigit()
                    ProgressView(value: recorder.level).tint(Palette.red)
                }
                if !recorder.livePreview.isEmpty {
                    Text(recorder.livePreview).font(.callout).foregroundStyle(Palette.muted)
                }
            }
            if case .failed(let why) = recorder.phase {
                Text(why).font(.footnote).foregroundStyle(Palette.red)
            }
            if recorder.phase == .done {
                TextField("Transcript", text: $recorder.transcript, axis: .vertical).lineLimit(3...20)
                if let source = recorder.transcriptSource {
                    Text("Transcript: \(source). Check it before sending.").font(.caption).foregroundStyle(Palette.muted)
                }
            }
        } header: {
            Text("Interview")
        } footer: {
            Text("Ask before you record. The recording and its transcript, made by Speech on this device, are sent; the transcript can be corrected first.")
        }
    }

    // MARK: Sending

    private var canSend: Bool {
        guard lanes.conductor != nil, !sender.state.isBusy, !preparingVideo else { return false }
        switch kind {
        case .photo: return image != nil
        case .video: return video != nil
        case .interview: return recorder.phase == .done && recorder.file != nil
        }
    }

    private func loadVideo(_ item: PhotosPickerItem) async {
        preparingVideo = true
        defer { preparingVideo = false; videoItem = nil }
        problem = nil
        guard let movie = try? await item.loadTransferable(type: PickedMovie.self) else {
            problem = "The video could not be read."; return
        }
        let small = await MediaPrep.compressedVideo(movie.url)
        video = small
        videoBytes = MediaPrep.size(small)
        if videoBytes > TalkWire.maxFileBytes { problem = TalkWire.Failure.tooLarge("The video", videoBytes).localizedDescription }
    }

    private func send() async {
        guard let lane = lanes.conductor else { return }
        problem = nil
        var attachments: [TalkWire.Attachment] = []
        var transcriptSource: String?
        switch kind {
        case .photo:
            guard let image, let jpeg = MediaPrep.jpeg(image, longestSide: 3000, quality: 0.8) else { problem = "The photo could not be prepared."; return }
            attachments.append(.init(kind: .image, name: "photo.jpg", data: jpeg))
        case .video:
            guard let video, let data = try? Data(contentsOf: video) else { problem = "The video could not be read."; return }
            attachments.append(.init(kind: .video, name: "video.\(video.pathExtension.isEmpty ? "mp4" : video.pathExtension)", data: data))
        case .interview:
            guard let file = recorder.file, let data = try? Data(contentsOf: file) else { problem = "The recording could not be read."; return }
            attachments.append(.init(kind: .audio, name: "interview.m4a", data: data))
            let transcript = recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                attachments.append(.init(kind: .transcript, name: "transcript.txt", data: Data(transcript.utf8)))
                transcriptSource = recorder.transcriptSource
            }
        }
        let item = TalkWire.itemId(purpose: .draft, town: town)
        let line = [title, notes].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
        do {
            lastMessages = try TalkWire.messages(item: item, purpose: .draft, to: "conductor", town: town,
                                                 townName: TalkTowns.name(town), title: title.isEmpty ? nil : title,
                                                 text: line, attachments: attachments, transcriptSource: transcriptSource,
                                                 app: TalkApp.line, signer: signingKey?().map(TalkWire.Signer.init(key:)))
        } catch {
            problem = error.localizedDescription
            return
        }
        lastRecord = TalkHistory.Record(id: item, purpose: .draft, town: town, text: line, files: attachments.map(\.name), status: .sent, at: .now)
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

    private func clear() {
        title = ""
        notes = ""
        image = nil
        video = nil
        videoBytes = 0
        if kind == .interview { recorder.discard() }
    }
}
