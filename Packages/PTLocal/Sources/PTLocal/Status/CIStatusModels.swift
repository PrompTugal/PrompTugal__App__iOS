import Foundation

/// ci-status.json, written by scripts/ci-status/collect.py and published by .github/workflows/ci-status.yml on the
/// `ci-status` branch about every ten minutes. Every field is optional: a field the collector could not read, or one
/// a later collector adds or drops, never hides the rest.
public struct CIStatus: Decodable, Sendable, Equatable {
    public var schema: Int?
    public var generatedAt: Date?
    public var generatedBy: String?
    public var repo: String?
    public var shipBranch: String?
    public var refreshMinutes: Int?
    public var available: Bool?
    public var reason: String?
    public var pipelines: [Pipeline]
    public var testflight: TestFlight?

    enum CodingKeys: String, CodingKey {
        case schema, generatedAt, generatedBy, repo, shipBranch, refreshMinutes, available, reason, pipelines, testflight
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try? c.decodeIfPresent(Int.self, forKey: .schema)
        generatedAt = CIStatus.date(try? c.decodeIfPresent(String.self, forKey: .generatedAt))
        generatedBy = try? c.decodeIfPresent(String.self, forKey: .generatedBy)
        repo = try? c.decodeIfPresent(String.self, forKey: .repo)
        shipBranch = try? c.decodeIfPresent(String.self, forKey: .shipBranch)
        refreshMinutes = try? c.decodeIfPresent(Int.self, forKey: .refreshMinutes)
        available = try? c.decodeIfPresent(Bool.self, forKey: .available)
        reason = try? c.decodeIfPresent(String.self, forKey: .reason)
        pipelines = (try? c.decodeIfPresent([CILenient<Pipeline>].self, forKey: .pipelines))?.compactMap(\.value) ?? []
        testflight = try? c.decodeIfPresent(TestFlight.self, forKey: .testflight)
    }

    /// The pipeline with this id: website, ios, release, news.
    public func pipeline(_ id: String) -> Pipeline? { pipelines.first { $0.id == id } }

    /// The latest TestFlight build of the app with this bundle id.
    public func testFlightBuild(bundle: String?) -> TestFlightBuild? {
        guard let bundle else { return nil }
        return testflight?.apps.values.first { $0.bundle == bundle }
    }

    nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        return isoFormatter.date(from: text)
    }

    // MARK: Pipelines and runs

    public struct Pipeline: Decodable, Sendable, Equatable, Identifiable {
        public var id: String
        public var title: String
        public var repo: String?
        public var workflow: String?
        public var url: String?
        public var available: Bool
        public var reason: String?
        public var liveLabel: String?
        public var runs: [Run]
        public var pushToLive: Timing?
        public var pushToUpload: Timing?

        enum CodingKeys: String, CodingKey {
            case id, title, repo, workflow, url, available, reason, liveLabel, runs, pushToLive, pushToUpload
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? id
            repo = try? c.decodeIfPresent(String.self, forKey: .repo)
            workflow = try? c.decodeIfPresent(String.self, forKey: .workflow)
            url = try? c.decodeIfPresent(String.self, forKey: .url)
            available = (try? c.decodeIfPresent(Bool.self, forKey: .available)) ?? false
            reason = try? c.decodeIfPresent(String.self, forKey: .reason)
            liveLabel = try? c.decodeIfPresent(String.self, forKey: .liveLabel)
            runs = (try? c.decodeIfPresent([CILenient<Run>].self, forKey: .runs))?.compactMap(\.value) ?? []
            pushToLive = try? c.decodeIfPresent(Timing.self, forKey: .pushToLive)
            pushToUpload = try? c.decodeIfPresent(Timing.self, forKey: .pushToUpload)
        }

        /// The newest run that pushed to the shipping branch and reached production, with its push-to-live.
        public var latestShipped: Run? { runs.first { $0.pushToLive?.seconds != nil } }
        /// A run on the shipping branch still going: a push on its way to production right now.
        public func inFlight(branch: String) -> Run? { runs.first { $0.running && $0.branch == branch && $0.event == "push" } }
    }

    public struct Timing: Decodable, Sendable, Equatable {
        public var latestSeconds: Int?
        public var medianSeconds: Int?
        public var fastestSeconds: Int?
        public var samples: Int?
    }

    public struct Run: Decodable, Sendable, Equatable, Identifiable {
        public var id: Int
        public var number: Int?
        public var url: String?
        public var event: String?
        public var branch: String?
        public var status: String?
        public var conclusion: String?
        public var startedAt: Date?
        public var finishedAt: Date?
        public var durationSeconds: Int?
        public var running: Bool
        public var commit: String?
        public var shortCommit: String?
        public var title: String?
        public var pushToLive: PushToLive?

        enum CodingKeys: String, CodingKey {
            case id, number, url, event, branch, status, conclusion, startedAt, finishedAt, durationSeconds, running,
                 commit, shortCommit, title, pushToLive
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            number = try? c.decodeIfPresent(Int.self, forKey: .number)
            url = try? c.decodeIfPresent(String.self, forKey: .url)
            event = try? c.decodeIfPresent(String.self, forKey: .event)
            branch = try? c.decodeIfPresent(String.self, forKey: .branch)
            status = try? c.decodeIfPresent(String.self, forKey: .status)
            conclusion = try? c.decodeIfPresent(String.self, forKey: .conclusion)
            startedAt = CIStatus.date(try? c.decodeIfPresent(String.self, forKey: .startedAt))
            finishedAt = CIStatus.date(try? c.decodeIfPresent(String.self, forKey: .finishedAt))
            durationSeconds = try? c.decodeIfPresent(Int.self, forKey: .durationSeconds)
            running = (try? c.decodeIfPresent(Bool.self, forKey: .running)) ?? false
            commit = try? c.decodeIfPresent(String.self, forKey: .commit)
            shortCommit = try? c.decodeIfPresent(String.self, forKey: .shortCommit)
            title = try? c.decodeIfPresent(String.self, forKey: .title)
            pushToLive = try? c.decodeIfPresent(PushToLive.self, forKey: .pushToLive)
        }

        public enum Outcome: Sendable { case running, success, failure, other }

        public var outcome: Outcome {
            if running { return .running }
            switch conclusion {
            case "success": return .success
            case "failure", "timed_out", "startup_failure": return .failure
            default: return .other
            }
        }

        /// What to say for the result: "running", "queued", "success", "failure", "cancelled".
        public var resultText: String {
            if running { return status == "in_progress" ? "running" : (status ?? "queued") }
            return conclusion ?? status ?? "unknown"
        }
    }

    public struct PushToLive: Decodable, Sendable, Equatable {
        public var seconds: Int?
        public var uploadSeconds: Int?
        public var processed: Bool?
    }

    // MARK: TestFlight

    public struct TestFlight: Decodable, Sendable, Equatable {
        public var available: Bool?
        public var reason: String?
        public var apps: [String: TestFlightBuild]

        enum CodingKeys: String, CodingKey { case available, reason, apps }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            available = try? c.decodeIfPresent(Bool.self, forKey: .available)
            reason = try? c.decodeIfPresent(String.self, forKey: .reason)
            let raw = (try? c.decodeIfPresent([String: CILenient<TestFlightBuild>].self, forKey: .apps)) ?? [:]
            apps = raw.compactMapValues(\.value)
        }
    }
}

public struct TestFlightBuild: Decodable, Sendable, Equatable {
    public var app: String?
    public var bundle: String?
    public var version: String?
    public var build: String?
    public var commit: String?
    public var uploadedAt: Date?
    public var processed: Bool
    public var processedAt: Date?
    public var pushedAt: Date?
    public var runNumber: Int?
    public var runUrl: String?

    enum CodingKeys: String, CodingKey {
        case app, bundle, version, build, commit, uploadedAt, processed, processedAt, pushedAt, runNumber, runUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try? c.decodeIfPresent(String.self, forKey: .app)
        bundle = try? c.decodeIfPresent(String.self, forKey: .bundle)
        version = try? c.decodeIfPresent(String.self, forKey: .version)
        // The build number is a string in the file; accept a number too.
        build = (try? c.decodeIfPresent(String.self, forKey: .build)) ?? (try? c.decodeIfPresent(Int.self, forKey: .build)).map { String($0) }
        commit = try? c.decodeIfPresent(String.self, forKey: .commit)
        uploadedAt = CIStatus.date(try? c.decodeIfPresent(String.self, forKey: .uploadedAt))
        processed = (try? c.decodeIfPresent(Bool.self, forKey: .processed)) ?? false
        processedAt = CIStatus.date(try? c.decodeIfPresent(String.self, forKey: .processedAt))
        pushedAt = CIStatus.date(try? c.decodeIfPresent(String.self, forKey: .pushedAt))
        runNumber = try? c.decodeIfPresent(Int.self, forKey: .runNumber)
        runUrl = try? c.decodeIfPresent(String.self, forKey: .runUrl)
    }
}

/// The build installed on this device, and whether TestFlight has a newer one.
public struct InstalledBuild: Sendable, Equatable {
    public var bundle: String?
    public var version: String?
    public var build: String?

    public init(bundle: String?, version: String?, build: String?) {
        self.bundle = bundle
        self.version = version
        self.build = build
    }

    public static func current(_ bundle: Bundle = .main) -> InstalledBuild {
        InstalledBuild(bundle: bundle.bundleIdentifier,
                       version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }

    public enum Update: Equatable, Sendable {
        /// TestFlight has a higher build number than the one installed.
        case available(String)
        case upToDate
        /// No TestFlight build is known for this app, or a build number is not a number (a local Xcode build).
        case unknown
    }

    /// Build numbers are compared as numbers (CFBundleVersion is the CI run number plus an offset).
    public func update(against latest: TestFlightBuild?) -> Update {
        guard let latestText = latest?.build, let latestNumber = Self.number(latestText),
              let build, let installed = Self.number(build) else { return .unknown }
        return latestNumber > installed ? .available(latestText) : .upToDate
    }

    /// "601" and "601.2" read as 601; anything else is not a CI build number.
    static func number(_ text: String) -> Int? {
        Int(text.split(separator: ".").first.map(String.init) ?? text)
    }
}

/// Decodes one element, or nil when it does not decode, so one bad row never hides a list.
struct CILenient<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
}
