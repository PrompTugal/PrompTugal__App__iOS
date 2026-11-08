import SGitVault
import SwiftUI

/// Debug → Vault traffic: every request, cache hit, hash check, decryption and key
/// derivation the Swift vault reader made, from `VaultTrafficLog`. Paths and sizes only;
/// the log never holds a key.
struct VaultTrafficPanel: View {
    @Environment(VaultTrafficLog.self) private var injected: VaultTrafficLog?
    var sample: [VaultTrafficEvent]?
    @State private var kinds: Set<VaultTrafficEvent.Kind> = Set(VaultTrafficEvent.Kind.allCases)
    @State private var query = ""
    @State private var pipelinePath: String?

    private var events: [VaultTrafficEvent] { sample ?? injected?.events ?? [] }

    var body: some View {
        let shown = events.filter { kinds.contains($0.kind) && (query.isEmpty || $0.path.localizedStandardContains(query)) }
        let slowest = shown.map(\.durationMs).max() ?? 1
        List {
            Section {
                StatGrid(minimum: 120) {
                    StatTile(label: "Requests", value: "\(events.filter { $0.kind == .request }.count)")
                    StatTile(label: "Cache hits", value: "\(events.filter { $0.kind == .cacheHit }.count)", tone: .good)
                    StatTile(label: "Decrypted", value: Bytes.format(events.filter { $0.kind == .decrypt }.reduce(0) { $0 + $1.bytes }))
                    StatTile(label: "Errors", value: "\(events.filter { $0.kind == .error }.count)",
                             tone: events.contains { $0.kind == .error } ? .bad : .good)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(VaultTrafficEvent.Kind.allCases, id: \.self) { kind in
                            FilterChip(title: kind.title, isOn: kinds.contains(kind), color: kind.color) {
                                if kinds.contains(kind) { kinds.remove(kind) } else { kinds.insert(kind) }
                            }
                        }
                    }
                }
            } footer: {
                Text("Tap an event to see the whole pipeline for its object: fetch, verify SHA-256, AES-GCM, inflate, JSON.")
            }
            if events.isEmpty {
                Section {
                    GapNote(title: "No vault traffic yet",
                            text: "Open a vault in the Vault section. Every request and decryption step will show here, with its timing and size.")
                        .listRowInsets(EdgeInsets())
                }
            }
            Section("\(shown.count) events") {
                ForEach(shown) { event in
                    Button { pipelinePath = event.path } label: { VaultEventRow(event: event, slowest: slowest) }
                        .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $query, prompt: "Filter by path")
        .navigationTitle("Vault traffic")
        .toolbar {
            if sample == nil, let injected {
                ToolbarItem(placement: .topBarTrailing) { Button("Clear", role: .destructive) { injected.clear() } }
            }
        }
        .sheet(item: Binding(get: { pipelinePath.map(IdentifiedPath.init) }, set: { pipelinePath = $0?.id })) { item in
            NavigationStack {
                DecryptPipelineView(path: item.id, events: events.filter { $0.path == item.id }.reversed())
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct IdentifiedPath: Identifiable { let id: String }

extension VaultTrafficEvent.Kind {
    var title: String {
        switch self {
        case .request: "Fetch"
        case .cacheHit: "Cache hit"
        case .verify: "Verify"
        case .decrypt: "Decrypt"
        case .keyDerivation: "Key derivation"
        case .error: "Error"
        }
    }

    var symbol: String {
        switch self {
        case .request: "arrow.down.circle"
        case .cacheHit: "internaldrive"
        case .verify: "checkmark.seal"
        case .decrypt: "lock.open"
        case .keyDerivation: "key"
        case .error: "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .request: Palette.blue
        case .cacheHit: Palette.muted
        case .verify: Palette.green
        case .decrypt: Palette.series(4)
        case .keyDerivation: Palette.amber
        case .error: Palette.red
        }
    }
}

struct VaultEventRow: View {
    let event: VaultTrafficEvent
    let slowest: Double

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: event.kind.symbol).foregroundStyle(event.kind.color).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.kind.title).font(.caption.weight(.semibold)).foregroundStyle(event.kind.color)
                    if let status = event.status { Text("\(status)").font(Typo.dataSmall) }
                    Spacer()
                    Text(Bytes.format(event.bytes)).font(Typo.dataSmall).foregroundStyle(Palette.muted)
                }
                Text(event.path).font(Typo.data).lineLimit(1).truncationMode(.middle)
                if !event.detail.isEmpty { Text(event.detail).font(.caption2).foregroundStyle(Palette.muted) }
                HStack {
                    TimingBar(value: event.durationMs, maxValue: slowest, color: event.kind.color)
                    Text("\(event.durationMs.formatted(.number.precision(.fractionLength(1)))) ms")
                        .font(Typo.dataSmall).foregroundStyle(Palette.muted).frame(width: 70, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One object's journey: fetch → verify SHA-256 → AES-GCM → inflate → JSON, as steps on a line,
/// each with what it took and what came out. Steps the log did not record are shown as not seen.
struct DecryptPipelineView: View {
    let path: String
    let events: [VaultTrafficEvent]

    private struct Step: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let event: VaultTrafficEvent?
    }

    private var steps: [Step] {
        func find(_ kind: VaultTrafficEvent.Kind, _ hint: String? = nil) -> VaultTrafficEvent? {
            events.first { $0.kind == kind && (hint == nil || $0.detail.localizedCaseInsensitiveContains(hint!)) }
        }
        let fetch = find(.request) ?? find(.cacheHit)
        return [
            Step(id: "fetch", title: fetch?.kind == .cacheHit ? "Read from cache" : "Fetch", symbol: "arrow.down.circle", event: fetch),
            Step(id: "verify", title: "Verify SHA-256", symbol: "checkmark.seal", event: find(.verify)),
            Step(id: "key", title: "Derive key", symbol: "key", event: find(.keyDerivation)),
            Step(id: "decrypt", title: "AES-256-GCM", symbol: "lock.open", event: find(.decrypt, "gcm") ?? find(.decrypt)),
            Step(id: "inflate", title: "Inflate", symbol: "arrow.up.left.and.arrow.down.right", event: find(.decrypt, "inflate")),
            Step(id: "json", title: "JSON", symbol: "curlybraces", event: find(.decrypt, "json")),
        ]
    }

    var body: some View {
        let total = events.reduce(0) { $0 + $1.durationMs }
        List {
            Section {
                Text(path).font(Typo.data).textSelection(.enabled)
                LabeledContent("Total time", value: "\(total.formatted(.number.precision(.fractionLength(1)))) ms")
            }
            Section("Pipeline") {
                ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                    HStack(alignment: .top, spacing: Space.m) {
                        VStack(spacing: 0) {
                            Image(systemName: step.symbol)
                                .foregroundStyle(step.event == nil ? Palette.rule : (step.event?.kind.color ?? Palette.ink))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Palette.paper2))
                            if offset < steps.count - 1 {
                                Rectangle().fill(Palette.rule).frame(width: 2, height: 22)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.subheadline.weight(.semibold))
                            if let event = step.event {
                                Text("\(Bytes.format(event.bytes)) · \(event.durationMs.formatted(.number.precision(.fractionLength(1)))) ms")
                                    .font(Typo.dataSmall).foregroundStyle(Palette.muted)
                                if !event.detail.isEmpty { Text(event.detail).font(.caption) }
                            } else {
                                Text("Not seen in the log").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if let error = events.first(where: { $0.kind == .error }) {
                Section("Error") { Text(error.detail).foregroundStyle(Palette.red) }
            }
        }
        .navigationTitle("Decrypt pipeline")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum VaultTrafficSamples {
    /// Made-up events in the shape the reader logs, for previews only. No real ids or keys.
    static let events: [VaultTrafficEvent] = {
        let object = "bare/data/obj-cas-imm-0000sample"
        return [
            VaultTrafficEvent(kind: .request, path: "bare/refs/ref-pid-sample", bytes: 547, durationMs: 182, status: 200,
                              detail: "GET, ref"),
            VaultTrafficEvent(kind: .keyDerivation, path: object, durationMs: 3.1, detail: "HKDF-SHA256 from the read key"),
            VaultTrafficEvent(kind: .request, path: object, bytes: 2_312, durationMs: 214, status: 200, detail: "GET, object"),
            VaultTrafficEvent(kind: .verify, path: object, bytes: 2_312, durationMs: 0.4, detail: "SHA-256 matches the object id"),
            VaultTrafficEvent(kind: .decrypt, path: object, bytes: 2_284, durationMs: 0.9, detail: "AES-256-GCM, read key, 2.3 KB → 2.3 KB"),
            VaultTrafficEvent(kind: .decrypt, path: object, bytes: 9_870, durationMs: 1.2, detail: "inflate, 2.3 KB → 9.9 KB"),
            VaultTrafficEvent(kind: .decrypt, path: object, bytes: 9_870, durationMs: 0.7, detail: "JSON, a tree of 14 entries"),
            VaultTrafficEvent(kind: .cacheHit, path: "bare/data/obj-cas-imm-0001sample", bytes: 812, durationMs: 0.2),
        ].reversed()
    }()
}

#Preview("Vault traffic") {
    NavigationStack { VaultTrafficPanel(sample: VaultTrafficSamples.events) }
}
