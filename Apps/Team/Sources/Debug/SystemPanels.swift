import Security
import SwiftUI
import UIKit
import WebKit

// MARK: - Bridge

/// Debug → Bridge: every message between a web page and the app, from the team session's BridgeLog.
struct BridgePanel: View {
    var body: some View { BridgeLogView() }
}

// MARK: - Storage

/// Debug → Storage: the cached feeds, the reader's files and each website's data, with sizes and ages.
struct StoragePanel: View {
    @Environment(DashboardData.self) private var data
    @State private var files: [StoredFile] = []
    @State private var websiteRecords: [(String, Int)] = []

    struct StoredFile: Identifiable, Sendable {
        let id: URL
        let area: String
        let name: String
        let bytes: Int
        let modified: Date?
    }

    var body: some View {
        List {
            Section("Feeds") {
                ForEach(data.feedSummaries, id: \.name) { feed in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(feed.name).font(Typo.data)
                            Spacer()
                            Text(feed.bytes > 0 ? Bytes.format(feed.bytes) : "not loaded").font(Typo.dataSmall)
                                .foregroundStyle(Palette.muted)
                        }
                        FreshnessLabel(updated: feed.updated, failed: { if case .failed = feed.phase { true } else { false } }())
                    }
                }
            }
            Section("Files (\(Bytes.format(files.reduce(0) { $0 + $1.bytes })))") {
                ForEach(files) { file in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(file.name).font(Typo.data)
                            Text(file.area).font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(Bytes.format(file.bytes)).font(Typo.dataSmall)
                            if let modified = file.modified {
                                Text(modified, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                                    .font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
            }
            Section {
                ForEach(websiteRecords, id: \.0) { site, count in
                    LabeledContent(site, value: "\(count) kinds of data")
                }
            } header: {
                Text("Website data in the web views")
            } footer: {
                Text("Cookies, local storage, IndexedDB and caches the websites keep, per site. Contents are not shown.")
            }
            Section {
                Button("Clear cached feeds", role: .destructive) {
                    try? FileManager.default.removeItem(at: FeedCache.directory)
                    Task { await scan() }
                }
            }
        }
        .navigationTitle("Storage")
        .task { await scan() }
        .refreshable { await scan() }
    }

    private func scan() async {
        let areas: [(String, URL)] = [
            ("Caches · feeds", FeedCache.directory),
            ("Application Support · reader", URL.applicationSupportDirectory.appendingPathComponent("PrompTugal")),
            ("Documents", URL.documentsDirectory),
        ]
        files = await Task.detached {
            var found: [StoredFile] = []
            let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
            for (area, root) in areas {
                guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { continue }
                for case let url as URL in walker {
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    guard values?.isRegularFile == true else { continue }
                    found.append(StoredFile(id: url, area: area, name: url.lastPathComponent,
                                            bytes: values?.fileSize ?? 0, modified: values?.contentModificationDate))
                }
            }
            return found.sorted { $0.bytes > $1.bytes }
        }.value
        let records = await WKWebsiteDataStore.default().dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        websiteRecords = records.map { ($0.displayName, $0.dataTypes.count) }.sorted { $0.0 < $1.0 }
    }
}

// MARK: - Keys

/// Debug → Keys: which keychain items exist, their service, account and protection.
/// The query asks for attributes only (`kSecReturnAttributes`), never for data, so no value
/// can reach this screen.
struct KeysPanel: View {
    @State private var items: [KeyItem] = []
    @State private var error: String?

    struct KeyItem: Identifiable {
        let id = UUID()
        let kind: String
        let service: String
        let account: String
        let protection: String
        let created: Date?
    }

    var body: some View {
        List {
            Section {
                Text("Names and protection only. The app never reads a key's value for this screen.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            Section("Collaboration and AI keys") {
                let rows = CollabDebugPanel.keyRows(keys: .shared, lanes: .shared)
                ForEach(rows.indices, id: \.self) { index in
                    LabeledContent(rows[index].0) {
                        Text(rows[index].1).font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
            let vaultKeys = VaultSession.shared.keyInventory
            if !vaultKeys.isEmpty {
                Section("Vault keys (from the vault session)") {
                    ForEach(vaultKeys) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(Typo.data)
                            Text(item.detail).font(.caption).foregroundStyle(Palette.muted)
                            HStack {
                                Label(item.store, systemImage: "internaldrive").font(.caption2).foregroundStyle(Palette.blue)
                                Label(item.protection, systemImage: "lock").font(.caption2).foregroundStyle(Palette.green)
                            }
                        }
                    }
                }
            }
            if items.isEmpty && vaultKeys.isEmpty {
                Section { Text(error ?? "No keys stored on this device yet.").foregroundStyle(Palette.muted) }
            }
            ForEach(Dictionary(grouping: items, by: \.kind).sorted { $0.key < $1.key }, id: \.key) { kind, rows in
                Section(kind) {
                    ForEach(rows) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.service.isEmpty ? "(no service)" : item.service).font(Typo.data)
                            Text(item.account).font(.caption).foregroundStyle(Palette.muted)
                            HStack {
                                Label(item.protection, systemImage: "lock").font(.caption2).foregroundStyle(Palette.green)
                                if let created = item.created {
                                    Text(created, format: .dateTime.day().month().hour().minute()).font(.caption2)
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Keys")
        .task { load() }
        .refreshable { load() }
    }

    private func load() {
        var found: [KeyItem] = []
        for (kind, secClass) in [("Passwords and tokens", kSecClassGenericPassword), ("Keys", kSecClassKey),
                                 ("Internet passwords", kSecClassInternetPassword)] {
            let query: [String: Any] = [
                kSecClass as String: secClass,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true,
                // Never ask for data: no kSecReturnData. Items behind Face ID are listed without prompting.
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let rows = result as? [[String: Any]] else { continue }
            for row in rows {
                found.append(KeyItem(kind: kind,
                                     service: row[kSecAttrService as String] as? String
                                        ?? row[kSecAttrLabel as String] as? String ?? "",
                                     account: row[kSecAttrAccount as String] as? String
                                        ?? (row[kSecAttrApplicationTag as String] as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? "",
                                     protection: Self.describe(row[kSecAttrAccessible as String] as? String),
                                     created: row[kSecAttrCreationDate as String] as? Date))
            }
        }
        items = found
    }

    private static func describe(_ accessible: String?) -> String {
        switch accessible {
        case String(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly): "passcode set, this device only"
        case String(kSecAttrAccessibleWhenUnlockedThisDeviceOnly): "when unlocked, this device only"
        case String(kSecAttrAccessibleWhenUnlocked): "when unlocked"
        case String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly): "after first unlock, this device only"
        case String(kSecAttrAccessibleAfterFirstUnlock): "after first unlock"
        default: accessible ?? "unknown"
        }
    }
}

// MARK: - Build

/// Debug → Build: what this binary was built from, and the versions of the sites it reads.
struct BuildPanel: View {
    @Environment(DashboardData.self) private var data

    var body: some View {
        List {
            Section("This app") {
                ForEach(BuildInfo.current.rows, id: \.label) { row in
                    LabeledContent(row.label) { Text(row.value).font(Typo.data).textSelection(.enabled) }
                }
                if let url = BuildInfo.current.commitURL {
                    Link("The commit on GitHub", destination: url)
                }
            }
            Section("The sites it reads") {
                LabeledContent("promptugal.news", value: data.status.value?.version ?? "not loaded")
                LabeledContent("Team site", value: data.team.value?.version ?? "not loaded")
                LabeledContent("Graph", value: data.graph.value?.version ?? "not loaded")
            }
            Section("Device") {
                LabeledContent("System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                LabeledContent("Model", value: UIDevice.current.model)
            }
        }
        .navigationTitle("Build")
        .task { await data.refreshAll() }
    }
}
