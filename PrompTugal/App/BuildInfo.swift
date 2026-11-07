import Foundation

/// What this binary was built from, for Debug → Build (contracts §8).
///
/// `Scripts/build-info.sh` runs as a build phase and writes `BuildInfo.json`
/// into the app bundle. When the file is missing (a preview, or a build that
/// skipped the phase) every field reads "unknown".
struct BuildInfo: Decodable, Sendable, Equatable {
    var commit: String
    var shortCommit: String
    var branch: String
    var dirty: Bool
    var commitDate: String?
    var commitCount: Int?
    /// The website release in `/VERSION` when the app was built, e.g. "v0.1.3".
    var siteRelease: String
    var builtAt: String
    /// "ci" or "local".
    var builder: String
    var ciRun: String?
    var configuration: String?

    /// App version and build number from Info.plist (MARKETING_VERSION, CURRENT_PROJECT_VERSION).
    var appVersion: String = BuildInfo.infoString("CFBundleShortVersionString")
    var appBuild: String = BuildInfo.infoString("CFBundleVersion")

    private enum CodingKeys: String, CodingKey {
        case commit, shortCommit, branch, dirty, commitDate, commitCount, siteRelease, builtAt, builder, ciRun,
             configuration
    }

    static let unknown = BuildInfo(commit: "unknown", shortCommit: "unknown", branch: "unknown", dirty: false,
                                   commitDate: nil, commitCount: nil, siteRelease: "unknown", builtAt: "unknown",
                                   builder: "unknown", ciRun: nil, configuration: nil)

    static let current: BuildInfo = load(from: .main)

    static func load(from bundle: Bundle) -> BuildInfo {
        guard let url = bundle.url(forResource: "BuildInfo", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return .unknown }
        return decode(data) ?? .unknown
    }

    static func decode(_ data: Data) -> BuildInfo? {
        guard var info = try? JSONDecoder().decode(BuildInfo.self, from: data) else { return nil }
        if info.commitDate?.isEmpty == true { info.commitDate = nil }
        if info.ciRun?.isEmpty == true { info.ciRun = nil }
        return info
    }

    /// The commit on GitHub, when it is a real commit.
    var commitURL: URL? {
        guard commit.count == 40, commit.allSatisfy(\.isHexDigit) else { return nil }
        return URL(string: "https://github.com/PrompTugal/PrompTugal__App__iOS/commit/\(commit)")
    }

    /// Rows for a debug panel, in display order. No secrets are in here.
    var rows: [(label: String, value: String)] {
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
