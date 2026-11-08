import Foundation

/// A website that publishes a manifest of its data files, and the rules for fetching them.
/// Every URL is built from the manifest's relative paths, and a path that could leave the site is refused.
public struct SyncSource: Sendable, Hashable {
    /// A short name, used for the folder on disk.
    public let id: String
    /// The site root, with a trailing slash.
    public let base: URL
    /// Where the manifest is, relative to `base`.
    public let manifestPath: String
    /// Hosts files may come from. Default: the host of `base`.
    public let allowedHosts: Set<String>

    public init(id: String, base: URL, manifestPath: String = "api/v1/manifest.json", allowedHosts: Set<String>? = nil) {
        self.id = id
        self.base = base.absoluteString.hasSuffix("/") ? base : (URL(string: base.absoluteString + "/") ?? base)
        self.manifestPath = manifestPath
        self.allowedHosts = allowedHosts ?? Set([base.host()].compactMap { $0 })
    }

    /// promptugal.news: `api/v1/manifest.json` lists every file of its JSON API with size and SHA-256.
    public static let promptugalNews = SyncSource(id: "promptugal.news", base: URL(string: "https://promptugal.news/")!)

    public var manifestURL: URL? { url(for: manifestPath) }

    /// The URL of a file, or nil when the path is unsafe or the result would leave the site (https only, allowed hosts only).
    public func url(for path: String) -> URL? {
        guard SyncPath.isSafe(path) else { return nil }
        let encoded = path.split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        guard let url = URL(string: encoded, relativeTo: base)?.absoluteURL,
              url.scheme == "https",
              let host = url.host(), allowedHosts.contains(host),
              url.absoluteString.hasPrefix(base.absoluteString) else { return nil }
        return url
    }
}

public enum SyncPath {
    /// A relative path of plain segments: no leading slash, no `.` or `..`, no empty segment, no backslash,
    /// no control characters, no `?`, `#` or `%`, and no `scheme:` in the first segment.
    public static func isSafe(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= 512, !path.hasPrefix("/"), !path.contains("\\"),
              !path.contains("?"), !path.contains("#"), !path.contains("%"),
              !path.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        for part in parts where part.isEmpty || part == "." || part == ".." { return false }
        if let first = parts.first, first.contains(":") { return false }
        return true
    }
}

/// Limits that stop a broken or hostile site from filling the device.
public enum SyncLimits {
    public static let maxManifestBytes = 8 * 1024 * 1024
    public static let maxFileBytes = 64 * 1024 * 1024
    public static let maxFiles = 20_000
}
