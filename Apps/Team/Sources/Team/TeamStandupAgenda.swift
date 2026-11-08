import Foundation

// The stand-ups, read from the team site's markdown twins: the list (`/meetings/index.md`) and each agenda
// (`/meetings/<slot>/index.md`). Like the other twins, these are written by the site's build and are regular;
// anything that does not match is skipped, so a changed page shows less, never a broken screen.

/// One row of the stand-up list: when, and what is open on its agenda.
struct StandupSummary: Identifiable, Hashable, Sendable {
    var id: String { slot }
    let slot: String                // "2026-11-08-1200"
    let label: String               // "2026-11-08 12:00": wins over the slot, as for `TeamStandup`
    let at: Date?
    let decisions: Int
    let questions: Int
    let ideas: Int
    let syncs: Int
    let decided: Int
    let isNext: Bool

    var openTotal: Int { decisions + questions + ideas + syncs }
    /// The stand-ups last about 30 minutes.
    var end: Date? { at?.addingTimeInterval(30 * 60) }
}

/// One item on a stand-up's agenda.
struct AgendaItem: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case decision = "Decisions", question = "Questions", idea = "Ideas", sync = "Quick syncs"
    }

    var id: String { "\(kind.rawValue)|\(title)" }
    let kind: Kind
    let title: String
    let carriedFrom: String?        // the slot it was first added to
    let forWhom: [String]           // person ids, or "everyone"
    let addedBy: String             // "conductor@web-summit.dinis"
    let detail: String
    let options: [String]
    let recommended: String
    let issue: String?              // "WS-15"
    let issueURL: URL?

    func isFor(_ person: String) -> Bool { forWhom.contains(person) || forWhom.contains("everyone") }
}

/// A person's briefing for the stand-up, with how many items name them.
struct AgendaBriefing: Identifiable, Hashable, Sendable {
    var id: String { person }
    let person: String              // "dinis"
    let name: String                // "Dinis Cruz"
    let items: Int
}

struct StandupAgenda: Hashable, Sendable {
    let slot: String
    let items: [AgendaItem]
    let briefings: [AgendaBriefing]

    func items(_ kind: AgendaItem.Kind) -> [AgendaItem] { items.filter { $0.kind == kind } }
}

extension TeamMarkdown {
    /// `| [2026-11-08 12:00](2026-11-08-1200/index.html) **next** | 21 · 6 · 1 · 7 | 0 |` rows of the stand-up list.
    static func standupSummaries(_ text: String) -> [StandupSummary] {
        var seen = Set<String>()
        var result: [StandupSummary] = []
        for line in text.split(separator: "\n") where line.hasPrefix("|") {
            // "| a | b | c |" splits into ["", a, b, c, ""]
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 4, let link = firstLink(in: Substring(cells[1])),
                  link.target.hasSuffix("/index.html") else { continue }
            let slot = String(link.target.dropLast("/index.html".count))
            guard !slot.contains("/"), seen.insert(slot).inserted else { continue }
            let counts = cells[2].split(separator: "·").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            func count(_ index: Int) -> Int { index < counts.count ? counts[index] : 0 }
            result.append(StandupSummary(
                slot: slot, label: link.text, at: TeamStandup(slot: slot, label: link.text)?.at,
                decisions: count(0), questions: count(1), ideas: count(2), syncs: count(3),
                decided: Int(cells[3]) ?? 0, isNext: cells[1].contains("**next**")))
        }
        return result.sorted { ($0.at ?? .distantPast) < ($1.at ?? .distantPast) }
    }

    /// `### Decisions` (or Questions, Ideas, Quick syncs) with one `- **title** …` bullet per item, then
    /// `## Everyone's briefing` with `- [Name](person/index.html): 31 items for them`.
    static func agenda(_ text: String, slot: String) -> StandupAgenda {
        var items: [AgendaItem] = []
        var briefings: [AgendaBriefing] = []
        var kind: AgendaItem.Kind?
        var inBriefings = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                kind = nil
                inBriefings = line.localizedCaseInsensitiveContains("briefing")
            } else if line.hasPrefix("### ") {
                let heading = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
                kind = AgendaItem.Kind.allCases.first { $0.rawValue.caseInsensitiveCompare(heading) == .orderedSame }
            } else if line.hasPrefix("- ") {
                let body = String(line.dropFirst(2))
                if inBriefings {
                    if let briefing = agendaBriefing(body) { briefings.append(briefing) }
                } else if let kind, let item = agendaItem(body, kind: kind, slot: slot) {
                    items.append(item)
                }
            }
        }
        return StandupAgenda(slot: slot, items: items, briefings: briefings)
    }

    /// `**title** *(carried over from 2026-11-03-1300)*. For: a, b. Added by x. Detail. Options: (1) …; (2) ….
    /// *Recommended:* … [WS-15](../../briefs/index.html#issues)`, every part after the title optional.
    private static func agendaItem(_ text: String, kind: AgendaItem.Kind, slot: String) -> AgendaItem? {
        guard text.hasPrefix("**"),
              let close = text.range(of: "**", range: text.index(text.startIndex, offsetBy: 2)..<text.endIndex) else { return nil }
        let title = String(text[text.index(text.startIndex, offsetBy: 2)..<close.lowerBound])
        guard !title.isEmpty else { return nil }
        var rest = String(text[close.upperBound...]).trimmingCharacters(in: .whitespaces)

        var carried: String?
        let carriedPrefix = "*(carried over from "
        if rest.hasPrefix(carriedPrefix), let end = rest.range(of: ")*") {
            carried = String(rest[rest.index(rest.startIndex, offsetBy: carriedPrefix.count)..<end.lowerBound])
            rest = String(rest[end.upperBound...])
        }
        // The title's closing "." and the spaces after it (or after the carried-over note) are not part of the text.
        while let first = rest.first, first == "." || first.isWhitespace { rest.removeFirst() }

        // The issue link closes the item: " [WS-15](../../briefs/index.html#issues)".
        var issue: String?
        var issueURL: URL?
        if rest.hasSuffix(")"), let open = rest.range(of: " [", options: .backwards) {
            let tail = rest[rest.index(after: open.lowerBound)...]
            if let link = firstLink(in: tail), tail.hasSuffix("](\(link.target))") {
                issue = link.text
                issueURL = URL(string: link.target, relativeTo: TeamEndpoints.url("meetings/\(slot)/index.html"))?.absoluteURL
                rest = String(rest[..<open.lowerBound])
            }
        }

        var recommended = ""
        if let marker = rest.range(of: "*Recommended:*", options: .backwards) {
            recommended = String(rest[marker.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            rest = String(rest[..<marker.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        var options: [String] = []
        if let marker = rest.range(of: "Options:", options: .backwards) {
            options = splitOptions(String(rest[marker.upperBound...]))
            rest = String(rest[..<marker.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        // What is left: "For: a, b. Added by x. Detail." A trailing space makes every sentence end in ". ".
        var detail = rest + " "
        var forWhom: [String] = []
        if detail.hasPrefix("For: "), let end = detail.range(of: ". ") {
            forWhom = detail[detail.index(detail.startIndex, offsetBy: 5)..<end.lowerBound]
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            detail = String(detail[end.upperBound...])
        }
        var addedBy = ""
        if detail.hasPrefix("Added by "), let end = detail.range(of: ". ") {
            addedBy = String(detail[detail.index(detail.startIndex, offsetBy: 9)..<end.lowerBound])
            detail = String(detail[end.upperBound...])
        }
        return AgendaItem(kind: kind, title: title, carriedFrom: carried, forWhom: forWhom, addedBy: addedBy,
                          detail: detail.trimmingCharacters(in: .whitespacesAndNewlines), options: options,
                          recommended: recommended, issue: issue, issueURL: issueURL)
    }

    /// "(1) protect main now; (2) leave it this week" → ["protect main now", "leave it this week"].
    private static func splitOptions(_ text: String) -> [String] {
        var starts: [Range<String.Index>] = []
        var cursor = text.startIndex
        while let match = text.range(of: #"\(\d+\) "#, options: .regularExpression, range: cursor..<text.endIndex) {
            starts.append(match)
            cursor = match.upperBound
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !starts.isEmpty else { return trimmed.isEmpty ? [] : [trimmed] }
        let separators = CharacterSet(charactersIn: ";. ").union(.whitespacesAndNewlines)
        return starts.enumerated().map { index, match in
            let end = index + 1 < starts.count ? starts[index + 1].lowerBound : text.endIndex
            return String(text[match.upperBound..<end]).trimmingCharacters(in: separators)
        }.filter { !$0.isEmpty }
    }

    /// `[Dinis Cruz](dinis/index.html): 31 items for them`.
    private static func agendaBriefing(_ text: String) -> AgendaBriefing? {
        guard let link = firstLink(in: Substring(text)), link.target.hasSuffix("/index.html") else { return nil }
        let person = String(link.target.dropLast("/index.html".count))
        guard !person.isEmpty, !person.contains("/") else { return nil }
        let tail = text.components(separatedBy: "): ").dropFirst().first ?? ""
        return AgendaBriefing(person: person, name: link.text, items: Int(tail.prefix { $0.isNumber }) ?? 0)
    }
}
