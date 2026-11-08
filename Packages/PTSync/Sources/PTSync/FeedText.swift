import Foundation

/// Text and links from a feed are untrusted. Everything shown comes out as plain text and https links.
enum FeedText {
    /// HTML to plain text: scripts and styles dropped, block ends become spaces, tags removed, entities decoded, white space
    /// collapsed, cut at a word boundary with "…" when longer than `limit`.
    static func plain(_ html: String, limit: Int) -> String {
        var text = html
        text = text.replacingOccurrences(of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<br\\s*/?>|</p>|</li>|</div>|</h[1-6]>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)   // tags that were escaped twice
        text = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return cut(text, limit: limit)
    }

    static func cut(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        let trimmed = head.lastIndex(of: " ").map { String(head[..<$0]) } ?? head
        return (trimmed.isEmpty ? head : trimmed).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "ndash": "–", "mdash": "—",
        "hellip": "…", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "copy": "©", "euro": "€",
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&"), let regex = try? NSRegularExpression(pattern: "&(#x[0-9a-fA-F]{1,6}|#[0-9]{1,7}|[a-zA-Z]{2,8});") else { return text }
        let source = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: last, length: match.range.location - last))
            let name = source.substring(with: match.range(at: 1))
            var replacement: String?
            if name.hasPrefix("#x") {
                replacement = UInt32(name.dropFirst(2), radix: 16).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
            } else if name.hasPrefix("#") {
                replacement = UInt32(name.dropFirst()).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
            } else {
                replacement = named[name.lowercased()]
            }
            result += replacement ?? source.substring(with: match.range)
            last = match.range.location + match.range.length
        }
        result += source.substring(from: last)
        return result
    }

    /// An absolute https URL without credentials, or nil. A relative link is resolved against `base`.
    static func safeURL(_ raw: String, base: URL) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 2_048,
              let url = URL(string: trimmed, relativeTo: base)?.absoluteURL,
              url.scheme == "https", let host = url.host(), !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    // MARK: Dates

    /// RFC 822 (RSS), ISO 8601 with or without fractions (Atom, JSON Feed), and a plain `yyyy-MM-dd`.
    static func date(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm:ss Z", "dd MMM yyyy HH:mm:ss zzz",
                       "EEE, d MMM yyyy HH:mm:ss zzz", "EEE, d MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm zzz", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
