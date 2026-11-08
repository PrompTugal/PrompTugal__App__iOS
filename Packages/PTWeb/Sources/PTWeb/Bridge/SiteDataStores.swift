import CryptoKit
import Foundation
import WebKit
import PTCore

/// One `WKWebsiteDataStore` per website (brief 05), so one site's storage, cookies and keys cannot be read by another.
///
/// Trade-off: promptugal.news stays on the default store, because that is where every earlier build kept its data
/// (the reader's schedule, reading meter and vault session). Every other site gets its own persistent store, made
/// from a fixed identifier per host. web-summit.sgit.ai's earlier data (the "Who are you?" choice `ws.me` and any
/// `ws-keyring` keys opened from a `#key=` link) stays behind in the default store: the app writes `ws.me` again from
/// the native identity, and a person re-opens their key link once.
public enum SiteDataStores {
    /// Hosts that keep the shared default store.
    public static let defaultStoreHosts: Set<String> = ["promptugal.news"]

    @MainActor
    public static func store(for url: URL) -> WKWebsiteDataStore {
        guard let host = url.host?.lowercased(), !defaultStoreHosts.contains(host) else { return .default() }
        return WKWebsiteDataStore(forIdentifier: identifier(for: host))
    }

    /// A stable identifier per host: the first 16 bytes of SHA-256("PrompTugal.site." + host), as a version-4-shaped UUID.
    public static func identifier(for host: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data("PrompTugal.site.\(host.lowercased())".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
