import Foundation

/// Reads the team site's markdown twins (`/meetings/index.md`, `/wakes/index.md`, `/reports/index.md`,
/// `/pulse/index.md`, `/log/index.md`). These pages publish no JSON; their markdown is regular, written by the
/// site's build, and these parsers follow it line by line. Anything that does not match is skipped.
enum TeamMarkdown {
    /// `| [2026-11-05 12:00](2026-11-05-1300/index.html) | … |` rows of the stand-up list.
    static func standups(_ text: String) -> [TeamStandup] {
        var seen = Set<String>()
        var result: [TeamStandup] = []
        for line in text.split(separator: "\n") where line.hasPrefix("|") {
            guard let link = firstLink(in: Substring(line)),
                  link.target.hasSuffix("/index.html") else { continue }
            let slot = String(link.target.dropLast("/index.html".count))
            guard !slot.contains("/"), seen.insert(slot).inserted,
                  let standup = TeamStandup(slot: slot, label: link.text) else { continue }
            result.append(standup)
        }
        return result.sorted { $0.at < $1.at }
    }

    /// `## agent`, then its schedule line, then `- 2026-11-06T22:29Z v0.2.893: text (https://…)` per wake.
    static func wakes(_ text: String) -> [AgentWakes] {
        var result: [AgentWakes] = []
        var agent: String?
        var schedule = ""
        var wakes: [AgentWakes.Wake] = []
        func flush() {
            if let agent { result.append(AgentWakes(agent: agent, schedule: schedule, wakes: wakes)) }
        }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                agent = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                schedule = ""
                wakes = []
            } else if agent != nil, line.hasPrefix("- ") {
                let body = line.dropFirst(2)
                let stamp = body.prefix { !$0.isWhitespace }
                var rest = body.dropFirst(stamp.count).trimmingCharacters(in: .whitespaces)
                var link: URL?
                if rest.hasSuffix(")"), let open = rest.range(of: " (https://", options: .backwards) {
                    link = URL(string: String(rest[rest.index(open.lowerBound, offsetBy: 2)..<rest.index(before: rest.endIndex)]))
                    rest = String(rest[..<open.lowerBound])
                }
                wakes.append(.init(at: ScheduleTime.parse(String(stamp)), text: rest, link: link))
            } else if agent != nil, schedule.isEmpty, !line.isEmpty, !line.hasPrefix("#") {
                schedule = line
            }
        }
        flush()
        return result
    }

    /// `- [title](path): summary` lines.
    static func reports(_ text: String) -> [TeamReport] {
        text.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("- ["), let link = firstLink(in: line) else { return nil }
            var summary = ""
            if let end = line.range(of: "](\(link.target))") {
                summary = line[end.upperBound...].trimmingCharacters(in: .whitespaces)
                if summary.hasPrefix(":") { summary = String(summary.dropFirst()).trimmingCharacters(in: .whitespaces) }
            }
            return TeamReport(title: link.text, path: link.target, summary: summary)
        }
    }

    /// `### Name, 2026-11-03-morning` followed by the check-in's markdown.
    static func pulse(_ text: String) -> [PulseEntry] {
        var result: [PulseEntry] = []
        var heading: String?
        var body: [Substring] = []
        func flush() {
            guard let heading, let comma = heading.range(of: ", ", options: .backwards) else { return }
            let entry = PulseEntry(who: String(heading[..<comma.lowerBound]), slot: String(heading[comma.upperBound...]),
                                   body: body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
            if !result.contains(where: { $0.id == entry.id }) { result.append(entry) }
        }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("### ") {
                flush()
                heading = String(line.dropFirst(4))
                body = []
            } else if line.hasPrefix("## ") || line.hasPrefix("# ") {
                flush()
                heading = nil
            } else if heading != nil {
                body.append(line)
            }
        }
        flush()
        return result
    }

    /// `## 2026-11-01T18:38:00Z: title`, a summary paragraph, then `- ` lines.
    static func log(_ text: String) -> [SessionLogEntry] {
        var result: [SessionLogEntry] = []
        var current: (at: Date?, title: String)?
        var summary = ""
        var lines: [String] = []
        func flush() {
            if let current { result.append(SessionLogEntry(at: current.at, title: current.title, summary: summary, lines: lines)) }
        }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                let heading = line.dropFirst(3)
                if let split = heading.range(of: "Z: ") {
                    let stamp = String(heading[..<split.lowerBound]) + "Z"
                    current = (ScheduleTime.parse(stamp), String(heading[split.upperBound...]))
                } else {
                    current = (nil, String(heading))
                }
                summary = ""
                lines = []
            } else if current != nil, line.hasPrefix("- ") {
                lines.append(String(line.dropFirst(2)))
            } else if current != nil, !line.isEmpty, lines.isEmpty {
                summary += summary.isEmpty ? line : " " + line
            }
        }
        flush()
        return result
    }

    /// The first `[text](target)` in a line.
    static func firstLink(in line: Substring) -> (text: String, target: String)? {
        guard let open = line.firstIndex(of: "["),
              let close = line[open...].range(of: "]("),
              let end = line[close.upperBound...].firstIndex(of: ")") else { return nil }
        return (String(line[line.index(after: open)..<close.lowerBound]), String(line[close.upperBound..<end]))
    }
}
