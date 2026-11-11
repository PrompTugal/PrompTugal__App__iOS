import Foundation

/// The only two hosts this app reads. Any other link opens in Safari, never in the app.
public enum FringeHosts {
    public static let events = URL(string: "https://lisbontechfringe.com/api/v1/events.json")!
    public static let storm = URL(string: "https://storm-charles.promptugal.news/api/v1/index.json")!
    public static let allowed: Set<String> = ["lisbontechfringe.com", "storm-charles.promptugal.news"]

    public static func isAllowed(_ url: URL) -> Bool {
        url.scheme == "https" && allowed.contains(url.host?.lowercased() ?? "")
    }
}
