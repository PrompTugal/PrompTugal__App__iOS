import Foundation

/// What this binary was built from, for Debug → Build (contracts §8).
///
/// `Scripts/build-info.sh` runs as a build phase and writes `BuildInfo.json`
/// into the app bundle. When the file is missing (a preview, or a build that
/// skipped the phase) every field reads "unknown".
public struct BuildInfo: Decodable, Sendable, Equatable {
    public var commit: String
    public var shortCommit: String
    public var branch: String
    public var dirty: Bool
    public var commitDate: String?
    public var commitCount: Int?
    /// The website release in `/VERSION` when the app was built, e.g. "v0.1.3".
    public var siteRelease: String
    public var builtAt: String
    /// "ci" or "local".
    public var builder: String
    public var ciRun: String?
    public var configuration: String?

    /// App version and build number from Info.plist (MARKETING_VERSION, CURRENT_PROJECT_VERSION).
    public var appVersion: String = BuildInfo.infoString("CFBundleShortVersionString")
    public var appBuild: String = BuildInfo.infoString("CFBundleVersion")

    public init(commit: String, shortCommit: String, branch: String, dirty: Bool, commitDate: String? = nil, commitCount: Int? = nil, siteRelease: String, builtAt: String, builder: String, ciRun: String? = nil, configuration: String? = nil, appVersion: String? = nil, appBuild: String? = nil) {
        self.commit = commit
        self.shortCommit = shortCommit
        self.branch = branch
        self.dirty = dirty
        self.commitDate = commitDate
        self.commitCount = commitCount
        self.siteRelease = siteRelease
        self.builtAt = builtAt
        self.builder = builder
        self.ciRun = ciRun
        self.configuration = configuration
        self.appVersion = appVersion ?? BuildInfo.infoString("CFBundleShortVersionString")
        self.appBuild = appBuild ?? BuildInfo.infoString("CFBundleVersion")
    }

    private enum CodingKeys: String, CodingKey {
        case commit, shortCommit, branch, dirty, commitDate, commitCount, siteRelease, builtAt, builder, ciRun,
             configuration
    }

    public static let unknown = BuildInfo(commit: "unknown", shortCommit: "unknown", branch: "unknown", dirty: false,
                                   commitDate: nil, commitCount: nil, siteRelease: "unknown", builtAt: "unknown",
                                   builder: "unknown", ciRun: nil, configuration: nil)

    public static let current: BuildInfo = load(from: .main)

    public static func load(from bundle: Bundle) -> BuildInfo {
        guard let url = bundle.url(forResource: "BuildInfo", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return .unknown }
        return decode(data) ?? .unknown
    }

    public static func decode(_ data: Data) -> BuildInfo? {
        guard var info = try? JSONDecoder().decode(BuildInfo.self, from: data) else { return nil }
        if info.commitDate?.isEmpty == true { info.commitDate = nil }
        if info.ciRun?.isEmpty == true { info.ciRun = nil }
        return info
    }

    /// The commit on GitHub, when it is a real commit.
    public var commitURL: URL? {
        guard commit.count == 40, commit.allSatisfy(\.isHexDigit) else { return nil }
        return URL(string: "https://github.com/PrompTugal/PrompTugal__App__iOS/commit/\(commit)")
    }

    /// Rows for a debug panel, in display order. No secrets are in here.
    public var rows: [(label: String, value: String)] {
        [("App version", "\(appVersion) (\(appBuild))"),
         ("Commit", shortCommit + (dirty ? " (uncommitted changes)" : "")),
         ("Branch", branch),
         ("Commit date", commitDate ?? "unknown"),
         ("Site release", siteRelease),
         ("Built", "\(builtAt), \(builder)\(configuration.map { ", \($0)" } ?? "")"),
         ("CI run", ciRun ?? "none")]
    }

    private static func infoString(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "unknown"
    }
}
