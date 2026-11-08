import Charts
import SwiftUI

/// Debug → Network: every request through the shared HTTPClient, and every page the
/// web views loaded, with timing bars and byte counts. URLs are already redacted.
struct NetworkPanel: View {
    private let log = HTTPLog.shared
    @State private var host = "all"
    @State private var failuresOnly = false
    @State private var query = ""
    @State private var selected: HTTPRequestRecord?

    private var records: [HTTPRequestRecord] {
        log.records.filter { record in
            (host == "all" || record.host == host)
                && (!failuresOnly || !record.succeeded)
                && (query.isEmpty || record.url.localizedStandardContains(query)
                    || (record.label ?? "").localizedStandardContains(query))
        }
    }

    private var hosts: [String] { Array(Set(log.records.map(\.host))).sorted() }

    var body: some View {
        let shown = records
        let slowest = shown.map(\.durationMs).max() ?? 1
        List {
            Section {
                StatGrid(minimum: 120) {
                    StatTile(label: "Requests", value: "\(log.totalRequests)")
                    StatTile(label: "Downloaded", value: Bytes.format(log.totalBytes))
                    StatTile(label: "Failed", value: "\(log.totalFailures)", tone: log.totalFailures > 0 ? .bad : .good)
                    StatTile(label: "Median time", value: median(shown.map(\.durationMs)).map { "\(Int($0)) ms" } ?? "–")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if !log.records.isEmpty { bytesByHost }
            }
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "All hosts", isOn: host == "all") { host = "all" }
                        ForEach(hosts, id: \.self) { name in
                            FilterChip(title: name, isOn: host == name, color: Palette.stable(name)) { host = name }
                        }
                        FilterChip(title: "Failures", isOn: failuresOnly, color: Palette.red) { failuresOnly.toggle() }
                    }
                }
            }
            Section("\(shown.count) requests, newest first") {
                if shown.isEmpty {
                    Text("No requests yet. Open a dashboard or pull to refresh.").foregroundStyle(Palette.muted)
                }
                ForEach(shown) { record in
                    Button { selected = record } label: { row(record, slowest: slowest) }
                        .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $query, prompt: "Filter by URL or label")
        .navigationTitle("Network")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) { log.clear() }
            }
        }
        .sheet(item: $selected) { record in
            NavigationStack { RequestDetail(record: record) }.presentationDetents([.medium, .large])
        }
    }

    private func row(_ record: HTTPRequestRecord, slowest: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Space.s) {
                Text(record.method).font(Typo.dataSmall.weight(.bold)).foregroundStyle(Palette.stable(record.method))
                Text(record.status.map(String.init) ?? "—")
                    .font(Typo.dataSmall)
                    .foregroundStyle(record.succeeded ? Palette.green : Palette.red)
                Text(path(record.url)).font(Typo.data).lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(Bytes.format(record.bytes)).font(Typo.dataSmall).foregroundStyle(Palette.muted)
            }
            HStack(spacing: Space.s) {
                TimingBar(value: record.durationMs, maxValue: slowest,
                          color: record.succeeded ? Palette.stable(record.host) : Palette.red)
                Text("\(Int(record.durationMs)) ms").font(Typo.dataSmall).foregroundStyle(Palette.muted)
                    .frame(width: 64, alignment: .trailing)
            }
            HStack {
                Text(record.host).font(.caption2).foregroundStyle(Palette.muted)
                if let label = record.label { Text("· \(label)").font(.caption2).foregroundStyle(Palette.muted) }
                Spacer()
                Text(record.startedAt, format: .dateTime.hour().minute().second()).font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var bytesByHost: some View {
        let totals = Dictionary(grouping: log.records, by: \.host)
            .map { (host: $0.key, bytes: $0.value.reduce(0) { $0 + $1.bytes }, count: $0.value.count) }
            .sorted { $0.bytes > $1.bytes }
        return Chart(totals, id: \.host) { item in
            BarMark(x: .value("Bytes", item.bytes), y: .value("Host", item.host))
                .foregroundStyle(Palette.stable(item.host))
                .annotation(position: .trailing) {
                    Text("\(Bytes.format(item.bytes)) · \(item.count)").font(.caption2).foregroundStyle(Palette.muted)
                }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(totals.count) * 28 + 10)
    }

    private func path(_ url: String) -> String {
        guard let components = URLComponents(string: url) else { return url }
        return components.path.isEmpty ? url : components.path
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.sorted()[values.count / 2]
    }
}

private struct RequestDetail: View {
    let record: HTTPRequestRecord
    var body: some View {
        List {
            LabeledContent("Method", value: record.method)
            LabeledContent("Status", value: record.status.map(String.init) ?? "none")
            LabeledContent("URL") { Text(record.url).font(Typo.data).textSelection(.enabled) }
            LabeledContent("Host", value: record.host)
            LabeledContent("Label", value: record.label ?? "none")
            LabeledContent("Bytes", value: "\(record.bytes.formatted()) (\(Bytes.format(record.bytes)))")
            LabeledContent("Time", value: "\(record.durationMs.formatted(.number.precision(.fractionLength(1)))) ms")
            LabeledContent("Started", value: record.startedAt.formatted(date: .omitted, time: .standard))
            if let error = record.error { LabeledContent("Error", value: error) }
            Section {
                Text("Query values are replaced with “…” and headers and bodies are never kept, so no key or token can show here.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}
