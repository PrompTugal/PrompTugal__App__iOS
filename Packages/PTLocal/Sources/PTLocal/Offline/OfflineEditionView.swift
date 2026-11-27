import PTCore
import SwiftUI

/// Offline edition: save the last edition of promptugal.news on this device (articles, since, every place, the
/// newsletter), each file checked against the site's manifest, so the app can be read with no connection. Shows the
/// edition's version, when it was saved, its size on disk, and a Delete button. Saves by itself only on Wi-Fi.
public struct OfflineEditionView: View {
    @State private var edition = OfflineEdition.shared
    @State private var askMobile = false
    @State private var confirmDelete = false

    public init() {}

    public var body: some View {
        List {
            Section {
                savedSummary
                progress
                saveButton
            } footer: {
                Text(LocalText.string("The same files for every reader, checked against promptugal.news's manifest. Nothing about you is sent. After the first save, the app saves a newer edition by itself, on Wi-Fi only."))
            }
            if edition.saved != nil {
                Section {
                    Button(LocalText.string("Delete the saved edition"), role: .destructive) { confirmDelete = true }
                }
            }
        }
        .navigationTitle(LocalText.string("Offline edition"))
        .task { await edition.refreshIfFree() }
        .confirmationDialog(LocalText.string("Save over mobile data?"), isPresented: $askMobile, titleVisibility: .visible) {
            Button(LocalText.string("Save now")) { Task { await edition.save() } }
            Button(LocalText.string("Cancel"), role: .cancel) {}
        } message: {
            Text(mobileMessage)
        }
        .confirmationDialog(LocalText.string("Delete the saved edition?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(LocalText.string("Delete"), role: .destructive) { edition.delete() }
            Button(LocalText.string("Cancel"), role: .cancel) {}
        } message: {
            Text(LocalText.string("The app then needs a connection to read promptugal.news."))
        }
    }

    @ViewBuilder private var savedSummary: some View {
        if let saved = edition.saved {
            VStack(alignment: .leading, spacing: 4) {
                Label(LocalText.string("Saved for offline, read \(String(describing: OfflineEditionText.day(saved.savedAt)))"), systemImage: "arrow.down.circle.fill")
                    .font(.headline).foregroundStyle(Palette.ink)
                Text(OfflineEditionText.detail(saved)).font(.footnote).foregroundStyle(Palette.muted)
            }
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label(LocalText.string("No edition saved"), systemImage: "arrow.down.circle").font(.headline).foregroundStyle(Palette.ink)
                Text(LocalText.string("Save the last edition to read the town pages with no connection. The other saved files wait on this device for the screens that will read them."))
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }
    }

    @ViewBuilder private var progress: some View {
        switch edition.state {
        case .saving(let done, let total):
            if total > 0 {
                ProgressView(value: Double(done), total: Double(total)) {
                    Text(LocalText.string("Saving \(String(describing: done)) of \(String(describing: total)) files")).font(.footnote)
                }
            } else {
                ProgressView(LocalText.string("Reading the manifest")).font(.footnote)
            }
        case .failed(let text):
            Text(text).font(.footnote).foregroundStyle(Palette.amber)
        case .idle:
            EmptyView()
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                if await edition.onMobileData() { askMobile = true } else { await edition.save() }
            }
        } label: {
            Label(edition.saved == nil ? LocalText.string("Save the edition") : LocalText.string("Save the newest edition"), systemImage: "square.and.arrow.down")
        }
        .disabled(edition.isSaving)
    }

    private var mobileMessage: String {
        let size = edition.plannedBytes ?? edition.saved?.bytes
        guard let size else { return LocalText.string("This uses mobile data, about 4 MB.") }
        return LocalText.string("This uses mobile data, about \(String(describing: OfflineEditionText.size(size))).")
    }
}

/// Plain text for the offline edition, testable.
enum OfflineEditionText {
    static func day(_ date: Date, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        "\(Freshness.day(date, now: now, timeZone: timeZone)), \(Freshness.time(date, timeZone: timeZone))"
    }

    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    static func detail(_ saved: SavedEdition) -> String {
        var parts: [String] = []
        if let version = saved.version { parts.append(LocalText.string("Edition \(String(describing: version))")) }
        parts.append("\(saved.files.count) files")
        parts.append(LocalText.string("\(String(describing: size(saved.bytes))) on this device"))
        return parts.joined(separator: " · ")
    }
}
