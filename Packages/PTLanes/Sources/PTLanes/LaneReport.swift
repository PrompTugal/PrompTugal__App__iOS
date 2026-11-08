import Foundation
import PTCore

/// Reporting a message or note someone else wrote (App Review 1.2).
enum LaneReport {
    /// Where reports go. Dinis has not given the address yet (decision 3 in the app-review pack); until then it is
    /// empty and the mail opens with no recipient, so the person can choose one. Set it here, once.
    static let contactAddress = ""

    /// A `mailto:` link with the subject and body filled in. Header-safe: line breaks only in the body.
    static func mailURL(kind: String, from sender: String, text: String, at date: Date? = nil,
                        to address: String = contactAddress) -> URL? {
        let subject = "Report: \(kind) from \(LaneMessage.header(sender).prefix(80))"
        var body = """
        I am reporting this \(kind) in the PrompTugal app.

        From: \(sender)
        """
        if let date { body += "\nSent: \(ISO8601DateFormatter().string(from: date))" }
        body += "\n\n---\n\(String(text.prefix(4_000)))\n---\n\nWhy I am reporting it:\n"
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = address
        parts.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return parts.url
    }
}
