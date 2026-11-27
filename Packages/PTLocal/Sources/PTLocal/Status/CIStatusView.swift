import PTCore
import SwiftUI

/// How long a push takes to reach production, for the website and the apps, and whether the build on this device has
/// a newer one in TestFlight. From ci-status.json (scripts/ci-status/collect.py, published by ci-status.yml), re-read
/// every minute while the screen is open. Read-only: nothing here starts or stops a workflow.
public struct CIStatusView: View {
    @State private var store = CIStatusStore.shared

    public init() {}

    public var body: some View {
        Page {
            ScreenHeader(kicker: LocalText.string("CI status"), title: LocalText.string("From push to production"),
                         summary: LocalText.string("A push to dev deploys the website and uploads the apps to TestFlight. How long each takes, what is running now, and whether this device needs the newer build."))
            CheckedLine(store: store)
            if let status = store.status {
                UpdateCard(installed: store.installed, latest: store.latestForThisApp, update: store.update)
                InFlight(status: status)
                tiles(status)
                TestFlightCard(status: status, installedBundle: store.installed.bundle)
                ForEach(status.pipelines) { pipeline in
                    PipelineCard(pipeline: pipeline)
                }
                GapNote(title: LocalText.string("Read-only, from GitHub Actions"),
                        text: LocalText.string("The numbers come from the workflows' own runs, read with the workflow token every ten minutes. Push to live is from the push to the moment the site serves the release, or App Store Connect has processed the build."))
            } else {
                StateView(phase: store.phase, hasData: false, title: LocalText.string("CI status")) {
                    Task { await store.refresh() }
                }
            }
        }
        .navigationTitle(LocalText.string("CI status"))
        .task {
            // Every minute while open: the collector writes about every ten minutes, so "checked N minutes ago" stays true.
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .refreshable { await store.refresh() }
    }

    private func tiles(_ status: CIStatus) -> some View {
        let site = status.pipeline("website")
        let ios = status.pipeline("ios")
        let news = status.pipeline("news")
        let newsDetail: String? = news?.available == true
            ? news?.pushToLive?.medianSeconds.map { LocalText.string("median \(String(describing: Self.duration($0)))") }
            : (news?.reason ?? LocalText.string("not read"))
        return StatGrid(minimum: 150) {
            StatTile(label: LocalText.string("Push to website live"), value: Self.duration(site?.pushToLive?.latestSeconds),
                     detail: site?.pushToLive?.medianSeconds.map { LocalText.string("median \(String(describing: Self.duration($0)))") } ?? site?.reason,
                     tone: site?.pushToLive == nil ? .neutral : .good)
            StatTile(label: LocalText.string("Push to TestFlight upload"), value: Self.duration(ios?.pushToUpload?.latestSeconds),
                     detail: ios?.pushToUpload?.medianSeconds.map { LocalText.string("median \(String(describing: Self.duration($0)))") } ?? ios?.reason)
            StatTile(label: LocalText.string("Push to TestFlight ready"), value: Self.duration(ios?.pushToLive?.latestSeconds),
                     detail: ios?.pushToLive?.medianSeconds.map { LocalText.string("median \(String(describing: Self.duration($0))), processed by Apple") } ?? LocalText.string("no processed build timed"),
                     tone: ios?.pushToLive == nil ? .neutral : .good)
            StatTile(label: LocalText.string("PrompTugal.news deploy"), value: Self.duration(news?.pushToLive?.latestSeconds),
                     detail: newsDetail)
        }
    }

    /// 1m 25s, 24m 36s, 1h 09m; a dash for no value.
    nonisolated static func duration(_ seconds: Int?) -> String {
        guard let seconds, seconds >= 0 else { return "–" }
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m " + String(format: "%02ds", seconds % 60) }
        return "\(seconds / 3600)h " + String(format: "%02dm", (seconds % 3600) / 60)
    }
}

// MARK: - Last checked

private struct CheckedLine: View {
    let store: CIStatusStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if store.phase == .loading { ProgressView().controlSize(.mini) }
                    Image(systemName: store.source.isLive ? "dot.radiowaves.left.and.right" : "wifi.slash")
                    if let checked = store.status?.generatedAt {
                        Text(LocalText.string("Last checked \(String(describing: Self.ago(checked, now: context.date)))"))
                            .fontWeight(.semibold)
                    } else {
                        Text(LocalText.string("Not checked yet"))
                    }
                }
                .foregroundStyle(stale(context.date) ? Palette.amber : Palette.ink)
                Text(store.source.label + (stale(context.date) ? LocalText.string(". The collector runs about every ten minutes; this is older than that.") : ""))
                    .foregroundStyle(Palette.muted)
            }
            .font(.footnote)
            .accessibilityElement(children: .combine)
        }
    }

    private func stale(_ now: Date) -> Bool {
        guard let checked = store.status?.generatedAt else { return true }
        return now.timeIntervalSince(checked) > 25 * 60
    }

    static func ago(_ date: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        switch minutes {
        case 0: return LocalText.string("just now")
        case 1: return LocalText.string("1 minute ago")
        case ..<120: return LocalText.string("\(String(describing: minutes)) minutes ago")
        default: return LocalText.string("\(String(describing: minutes / 60)) hours ago")
        }
    }
}

// MARK: - This device's build

private struct UpdateCard: View {
    let installed: InstalledBuild
    let latest: TestFlightBuild?
    let update: InstalledBuild.Update

    var body: some View {
        TitledCard(LocalText.string("This device"), kicker: LocalText.string("Installed build")) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(installed.version ?? "?") (\(installed.build ?? "?"))").font(.title3.monospacedDigit().weight(.semibold))
                    Text(installed.bundle ?? "").font(.caption.monospaced()).foregroundStyle(Palette.muted)
                }
                Spacer()
                badge
            }
            if let latest {
                Text(Self.latestLine(latest))
                    .font(.footnote).foregroundStyle(Palette.muted)
            } else {
                Text(LocalText.string("No TestFlight upload of this app in the latest runs on dev.")).font(.footnote).foregroundStyle(Palette.muted)
            }
            if case .available = update, let testFlight = URL(string: "itms-beta://") {
                Link(destination: testFlight) {
                    Label(LocalText.string("Open TestFlight to update"), systemImage: "arrow.down.app")
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .accessibilityIdentifier("pt.status.update")
    }

    static func latestLine(_ latest: TestFlightBuild) -> String {
        var parts: [String] = [LocalText.string("Latest in TestFlight: \(String(describing: latest.version ?? "?")) (\(String(describing: latest.build ?? "?")))")]
        if let uploaded = latest.uploadedAt {
            parts.append("uploaded " + uploaded.formatted(.relative(presentation: .named)))
        }
        parts.append(latest.processed ? "processed" : LocalText.string("processing or unknown"))
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private var badge: some View {
        switch update {
        case .available(let build):
            CountPill(count: Int(build) ?? 0, label: LocalText.string("update available"), color: Palette.amber)
                .accessibilityLabel(LocalText.string("Update available: build \(String(describing: build))"))
        case .upToDate:
            Label(LocalText.string("Up to date"), systemImage: "checkmark.seal").font(.footnote.weight(.semibold)).foregroundStyle(Palette.green)
        case .unknown:
            Label(LocalText.string("Not a TestFlight build"), systemImage: "questionmark.circle").font(.footnote).foregroundStyle(Palette.muted)
        }
    }
}

// MARK: - A push on its way

private struct InFlight: View {
    let status: CIStatus

    struct Flight: Identifiable {
        let pipeline: CIStatus.Pipeline
        let run: CIStatus.Run
        var id: String { "\(pipeline.id)-\(run.id)" }
    }

    var body: some View {
        let branch = status.shipBranch ?? "dev"
        let running: [Flight] = status.pipelines.compactMap { p in p.inFlight(branch: branch).map { Flight(pipeline: p, run: $0) } }
        if !running.isEmpty {
            TitledCard(LocalText.string("On its way now"), kicker: LocalText.string("A push to \(String(describing: branch))")) {
                ForEach(running) { flight in
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(flight.pipeline.title).font(.footnote.weight(.medium))
                        Spacer()
                        Text(LocalText.string("\(String(describing: flight.run.resultText)) for \(String(describing: CIStatusView.duration(flight.run.durationSeconds))) at check"))
                            .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
    }
}

// MARK: - TestFlight builds

private struct TestFlightCard: View {
    let status: CIStatus
    let installedBundle: String?

    var body: some View {
        let apps = (status.testflight?.apps ?? [:]).sorted { $0.key < $1.key }
        TitledCard(LocalText.string("Latest TestFlight build per app"), kicker: LocalText.string("\(String(describing: apps.count)) apps")) {
            if apps.isEmpty {
                Text(status.testflight?.reason ?? LocalText.string("No upload found in the latest runs on dev."))
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            ForEach(apps, id: \.key) { key, build in
                HStack(alignment: .firstTextBaseline) {
                    Text(key).font(.footnote.monospaced().weight(build.bundle == installedBundle ? .bold : .regular))
                    Spacer()
                    Text("\(build.version ?? "?") (\(build.build ?? "?"))").font(.footnote.monospacedDigit())
                    Image(systemName: build.processed ? "checkmark.circle" : "clock")
                        .foregroundStyle(build.processed ? Palette.green : Palette.muted)
                        .accessibilityLabel(build.processed ? "Processed" : LocalText.string("Processing or unknown"))
                }
            }
        }
    }
}

// MARK: - One workflow

private struct PipelineCard: View {
    let pipeline: CIStatus.Pipeline

    var body: some View {
        TitledCard(pipeline.title, kicker: pipeline.workflow ?? "workflow") {
            if !pipeline.available {
                Text(LocalText.string("Not readable: \(String(describing: pipeline.reason ?? "unknown"))")).font(.footnote).foregroundStyle(Palette.muted)
            }
            ForEach(pipeline.runs.prefix(6)) { run in
                RunRow(run: run, liveLabel: pipeline.liveLabel)
                if run.id != pipeline.runs.prefix(6).last?.id { Divider() }
            }
        }
    }
}

private struct RunRow: View {
    let run: CIStatus.Run
    let liveLabel: String?

    var body: some View {
        let row = VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text("#\(run.number.map { String($0) } ?? "?")").font(.footnote.monospacedDigit().weight(.semibold))
                Text(run.branch ?? "").font(.caption.monospaced()).lineLimit(1)
                Spacer()
                Text(run.resultText).font(.caption).foregroundStyle(color)
                Text(CIStatusView.duration(run.durationSeconds) + (run.running ? LocalText.string(" so far") : ""))
                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
            }
            if let seconds = run.pushToLive?.seconds {
                Text(LocalText.string("Push to \(String(describing: liveLabel ?? "live")): \(String(describing: CIStatusView.duration(seconds)))")).font(.caption.weight(.semibold)).foregroundStyle(Palette.green)
            } else if let upload = run.pushToLive?.uploadSeconds {
                Text(LocalText.string("Push to TestFlight upload: \(String(describing: CIStatusView.duration(upload)))")).font(.caption).foregroundStyle(Palette.muted)
            }
            Text([run.shortCommit, run.title].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        if let link = run.url.flatMap(URL.init(string:)), link.scheme == "https" {
            Link(destination: link) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }

    private var color: Color {
        switch run.outcome {
        case .running: Palette.blue
        case .success: Palette.green
        case .failure: Palette.red
        case .other: Palette.muted
        }
    }
}
