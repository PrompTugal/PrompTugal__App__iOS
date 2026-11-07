import SwiftUI
import UIKit

struct WebsiteShortcut: Decodable, Identifiable {
    let id: String
    let name: String
    let url: URL
    let icon: String
    let color: String
    let iconAsset: String?
    let iconText: String?

    @MainActor var symbol: String { UIImage(systemName: icon) == nil ? "globe" : icon }

    var tint: Color {
        switch color {
        case "red": .red
        case "orange": .orange
        case "green": .green
        case "teal": .teal
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        default: .accentColor
        }
    }

    var isValid: Bool {
        !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && url.scheme == "https" && url.host != nil && url.user == nil && url.password == nil
    }
}

struct WebsiteDirectory {
    let shortcuts: [WebsiteShortcut]
    let notice: String?

    static func load() -> Self {
        let filename = "Websites.json"
        guard let bundled = Bundle.main.url(forResource: "Websites", withExtension: "json"),
              let data = try? Data(contentsOf: bundled),
              let defaults = decode(data) else {
            return Self(shortcuts: [
                WebsiteShortcut(id: "promptugal", name: "PrompTugal.news", url: FeedClient.site,
                                icon: "newspaper.fill", color: "red", iconAsset: nil, iconText: nil)
            ], notice: "The bundled shortcuts file is unavailable.")
        }

        let override = URL.documentsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: override.path) {
            var custom: [WebsiteShortcut]?
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: override, options: [], error: &coordinationError) { url in
                if let data = try? Data(contentsOf: url) { custom = decode(data) }
            }
            guard coordinationError == nil, let custom else {
                return Self(shortcuts: defaults, notice: "Websites.json is invalid. The default shortcuts are shown.")
            }
            return Self(shortcuts: custom.map { applyingDefaults(to: $0, from: defaults) }, notice: nil)
        }

        do {
            try data.write(to: override, options: .withoutOverwriting)
            return Self(shortcuts: defaults, notice: nil)
        } catch {
            return Self(shortcuts: defaults, notice: "The shortcuts file could not be copied to Files.")
        }
    }

    private static func applyingDefaults(to shortcut: WebsiteShortcut, from defaults: [WebsiteShortcut]) -> WebsiteShortcut {
        guard let bundled = defaults.first(where: { $0.id == shortcut.id }) else { return shortcut }

        let legacySummit = shortcut.id == "summit-team"
            && ["https://summit-team.sgit.ai/", "https://summit-team.sgit.ai"].contains(shortcut.url.absoluteString)
        let url = legacySummit ? bundled.url : shortcut.url
        let name = legacySummit && shortcut.name == "summit-team.sgit.ai" ? bundled.name : shortcut.name
        let inheritsArtwork = shortcut.icon == bundled.icon && url.host == bundled.url.host
            && shortcut.iconAsset == nil && shortcut.iconText == nil

        return WebsiteShortcut(id: shortcut.id, name: name, url: url, icon: shortcut.icon, color: shortcut.color,
                               iconAsset: inheritsArtwork ? bundled.iconAsset : shortcut.iconAsset,
                               iconText: inheritsArtwork ? bundled.iconText : shortcut.iconText)
    }

    private static func decode(_ data: Data) -> [WebsiteShortcut]? {
        guard let shortcuts = try? JSONDecoder().decode([WebsiteShortcut].self, from: data),
              !shortcuts.isEmpty, shortcuts.allSatisfy(\.isValid),
              Set(shortcuts.map(\.id)).count == shortcuts.count else { return nil }
        return shortcuts
    }
}

struct WebsiteSidebar: View {
    let directory: WebsiteDirectory
    let selectedID: String?
    let select: (WebsiteShortcut) -> Void

    var body: some View {
        List {
            Section {
                ForEach(directory.shortcuts) { shortcut in
                    let selected = shortcut.id == selectedID
                    Button {
                        select(shortcut)
                    } label: {
                        Label {
                            Text(shortcut.name)
                                .fontWeight(selected ? .semibold : .regular)
                                .foregroundStyle(.primary)
                        } icon: {
                            ShortcutBadge(shortcut: shortcut).accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selected ? Color.accentColor.opacity(0.12) : Color.clear)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            } header: {
                Text("Websites").font(.headline).accessibilityAddTraits(.isHeader)
            } footer: {
                if let notice = directory.notice {
                    Text(notice)
                }
            }
        }
        .listStyle(.sidebar)
    }
}


private struct ShortcutBadge: View {
    let shortcut: WebsiteShortcut

    var body: some View {
        Group {
            if let asset = shortcut.iconAsset, let image = UIImage(named: asset) {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let text = shortcut.iconText, !text.isEmpty {
                Text(verbatim: text)
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 2)
            } else {
                Image(systemName: shortcut.symbol)
                    .font(.system(size: 17, weight: .semibold))
            }
        }
        .foregroundStyle(shortcut.tint)
        .frame(width: 36, height: 36)
        .background(shortcut.tint.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
