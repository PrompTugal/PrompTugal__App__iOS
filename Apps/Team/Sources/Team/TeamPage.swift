import Foundation

// A team-site page, read from its markdown twin (`/<path>/index.md`) and drawn natively. The twins are plain
// markdown written by the site's build: headings, paragraphs, bullet and numbered lists, tables, quotes and code.
// Anything the parser does not know is kept as a paragraph, so a changed page reads differently, never breaks.

enum TeamPageBlock: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case table(header: [String], rows: [[String]])
    case quote(String)
    case code(String)
    case rule
}

struct TeamPageItem: Identifiable, Hashable, Sendable {
    let id: Int
    let block: TeamPageBlock
}

struct TeamPage: Hashable, Sendable {
    let title: String
    let items: [TeamPageItem]

    init(markdown text: String) {
        let blocks = TeamPageParser.blocks(text)
        title = blocks.compactMap { block -> String? in
            if case .heading(let level, let text) = block, level == 1 { return text }
            return nil
        }.first ?? ""
        items = blocks.enumerated().map { TeamPageItem(id: $0.offset, block: $0.element) }
    }

    var isEmpty: Bool { items.isEmpty }
}

enum TeamPageParser {
    static func blocks(_ text: String) -> [TeamPageBlock] {
        var blocks: [TeamPageBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var quote: [String] = []
        var table: [[String]] = []
        var code: [String] = []
        var inCode = false

        func flushText() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: " "))); quote = [] }
            if !table.isEmpty {
                // the second row is the "|---|---|" separator and was dropped while reading
                blocks.append(.table(header: table[0], rows: Array(table.dropFirst())))
                table = []
            }
        }

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(code.joined(separator: "\n")))
                    code = []
                } else {
                    flushText()
                }
                inCode.toggle()
                continue
            }
            if inCode { code.append(line); continue }

            if trimmed.isEmpty { flushText(); continue }

            if let heading = Self.heading(trimmed) {
                flushText()
                blocks.append(heading)
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushText()
                blocks.append(.rule)
            } else if trimmed.hasPrefix("|") {
                if !paragraph.isEmpty || !bullets.isEmpty || !numbered.isEmpty || !quote.isEmpty { flushText() }
                let cells = Self.cells(trimmed)
                if cells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } }) { continue }      // the separator row
                table.append(cells)
            } else if trimmed.hasPrefix("> ") || trimmed == ">" {
                if !table.isEmpty || !paragraph.isEmpty || !bullets.isEmpty || !numbered.isEmpty { flushText() }
                quote.append(String(trimmed.dropFirst(trimmed.hasPrefix("> ") ? 2 : 1)))
            } else if let item = Self.bullet(trimmed) {
                if !table.isEmpty || !paragraph.isEmpty || !numbered.isEmpty || !quote.isEmpty { flushText() }
                // an indented bullet belongs under the one above it
                bullets.append(line.hasPrefix(" ") && !bullets.isEmpty ? "– " + item : item)
            } else if let item = Self.numberedItem(trimmed) {
                if !table.isEmpty || !paragraph.isEmpty || !bullets.isEmpty || !quote.isEmpty { flushText() }
                numbered.append(item)
            } else if line.hasPrefix(" "), !bullets.isEmpty {
                bullets[bullets.count - 1] += " " + trimmed                 // a list item that continues
            } else if line.hasPrefix(" "), !numbered.isEmpty {
                numbered[numbered.count - 1] += " " + trimmed
            } else {
                if !table.isEmpty || !bullets.isEmpty || !numbered.isEmpty || !quote.isEmpty { flushText() }
                paragraph.append(trimmed)
            }
        }
        if inCode { blocks.append(.code(code.joined(separator: "\n"))) }
        flushText()
        return blocks
    }

    /// `## The rules {#rules}` → level 2, "The rules".
    private static func heading(_ line: String) -> TeamPageBlock? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count), line.dropFirst(hashes.count).hasPrefix(" ") else { return nil }
        var text = line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
        if text.hasSuffix("}"), let open = text.range(of: " {#", options: .backwards) {
            text = String(text[..<open.lowerBound])
        }
        return .heading(level: hashes.count, text: text)
    }

    private static func bullet(_ line: String) -> String? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") else { return nil }
        return String(line.dropFirst(2))
    }

    private static func numberedItem(_ line: String) -> String? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3, line.dropFirst(digits.count).hasPrefix(". ") else { return nil }
        return String(line.dropFirst(digits.count + 2))
    }

    /// `| a | b |` → ["a", "b"].
    private static func cells(_ line: String) -> [String] {
        var parts = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.first == "" { parts.removeFirst() }
        if parts.last == "" { parts.removeLast() }
        return parts
    }
}
