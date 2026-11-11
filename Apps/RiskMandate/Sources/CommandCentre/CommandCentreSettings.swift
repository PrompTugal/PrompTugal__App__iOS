import Foundation

/// Where the command centre lives. One HTTPS address, kept per device in UserDefaults,
/// so a team member can point the app at their own /people/<id>/app/.
enum CommandCentreSettings {
    static let defaultAddress = "https://web-summit.sgit.ai/people/silvio/app/index.html#xray"
    static let defaultURL = URL(string: defaultAddress)!
    /// The UserDefaults key behind `@AppStorage`.
    static let addressKey = "commandCentreAddress"

    /// The address to open: the stored one if it is a valid HTTPS URL, otherwise the default.
    static func url(from stored: String) -> URL {
        validURL(stored) ?? defaultURL
    }

    /// An HTTPS URL with a host, or nil. A bare host ("example.com/x") gets https:// in front.
    static func validURL(_ text: String) -> URL? {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
