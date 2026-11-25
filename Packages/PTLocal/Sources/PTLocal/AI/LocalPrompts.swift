import Foundation

// The words sent to Apple's on-device model, built from a place's by-place JSON (promptugal.news/data/by-place/<id>.json)
// as PlaceSite decodes it. Pure functions, so tests can read exactly what the model is given. The model's context is
// small (about 4,096 tokens), so each prompt keeps to a character budget and says what it left out.
// The instruction style follows VoiceDebrief's Lab desks (LabAskDesk.swift, Apache License 2.0): say what to use, what
// not to invent, and the shape of the answer.

public enum LocalPrompts {
    /// Characters of facts in one prompt; leaves room for the instructions and the answer.
    static let budget = 6_000

    public static let townInstructions = """
    You summarise one town's page from PrompTugal.news, an independent site about AI and technology in Portugal. \
    Use only the facts given below; never add facts, names, numbers or dates that are not there. \
    Write one paragraph of at most 120 words, in plain English prose: no lists, no headings, no markdown. \
    If the page says the town is still being researched, say so.
    """

    public static let storyInstructions = """
    You summarise one local news story for PrompTugal.news. Use only the text given; never add facts. \
    Write two or three plain sentences, no markdown. Say who did what, where and when, if the text says it.
    """

    public static let aiPathInstructions = """
    You explain to a general reader why a local story is on PrompTugal.news, a site that only covers stories that \
    connect to artificial intelligence within three steps (the "AI path"). Use only the text given; never add facts. \
    Write three or four plain sentences, no markdown: what the story is, then each step from it to AI, in order.
    """

    public static let personaInstructions = """
    You brief one reader on what matters to them in the Algarve's AI news, from PrompTugal.news. \
    Use only the items given below; never add facts. Write one paragraph of at most 120 words, plain prose, no markdown. \
    Speak to the reader as "you". Lead with the items that match what they told you about themselves, and name them.
    """

    /// A town's page as facts, for the town summary. `persona` (what the reader said about themselves) asks the model
    /// to lead with what matters to them.
    public static func town(_ site: PlaceSite, persona: Persona? = nil) -> String {
        var lines: [String] = []
        lines.append("Town: \(site.name) (\(site.isLive ? "live site" : "still being researched by its agent")). Updated \(site.updated).")
        if !site.mandate.isEmpty { lines.append("Mandate: \(site.mandate)") }
        if let gravity = site.gravity?.text, !gravity.isEmpty { lines.append("Centre of gravity: \(gravity)") }
        // Stories under a rights hold are not given to the model: nothing may be drawn from them.
        let shown = site.aiNews.filter { !$0.isHeld }
        if !shown.isEmpty {
            lines.append("Local AI stories:")
            for story in shown {
                var line = "- \(story.title)"
                if let date = story.date { line += " (\(date)\(story.publisher.map { ", " + $0 } ?? ""))" }
                if let summary = story.summary { line += ": \(summary)" }
                if let path = story.aiPath { line += " AI path: \(path)" }
                lines.append(line)
            }
        }
        if !site.aiMap.isEmpty {
            lines.append("Organisations on the town's AI map:")
            for entry in site.aiMap {
                lines.append("- \(entry.name)\(entry.type.map { " (\($0))" } ?? "")\(entry.what.map { ": \($0)" } ?? "")")
            }
        }
        if !site.events.isEmpty {
            lines.append("Events: " + site.events.prefix(6).map { $0.title + ($0.date.map { " (\($0))" } ?? "") }.joined(separator: "; "))
        }
        if !site.gaps.isEmpty {
            lines.append("Not known yet: " + site.gaps.prefix(3).joined(separator: " "))
        }
        var text = fit(lines)
        if let persona { text += "\n\nThe reader says: \"\(persona.text)\". Lead with what matters to them, if anything does." }
        return text + "\n\nSummarise \(site.name) in one paragraph."
    }

    public static func story(_ story: PlaceSite.News, town: String?) -> String {
        var lines = ["Headline: \(story.title)"]
        if let town { lines.append("Town: \(town)") }
        if let publisher = story.publisher { lines.append("Published by: \(publisher)\(story.date.map { ", " + $0 } ?? "")") }
        if let summary = story.summary { lines.append("Summary: \(summary)") }
        if let path = story.aiPath { lines.append("AI path: \(path)") }
        return fit(lines) + "\n\nSummarise this story."
    }

    public static func aiPath(_ story: PlaceSite.News, town: String?) -> String {
        var lines = ["Headline: \(story.title)"]
        if let town { lines.append("Town: \(town)") }
        if let summary = story.summary { lines.append("Summary: \(summary)") }
        lines.append("Steps to AI: \(story.stepsLabel ?? "not given")")
        lines.append("AI path, as the newsroom wrote it: \(story.aiPath ?? "not given")")
        return fit(lines) + "\n\nExplain the AI path of this story."
    }

    /// The reader's persona and the items the ranking found for it, best first.
    public static func persona(_ persona: Persona, stories: [RankedStory], entries: [RankedEntry]) -> String {
        var lines = ["The reader says: \"\(persona.text)\""]
        if !stories.isEmpty {
            lines.append("Stories that match, best first:")
            for item in stories where !item.story.isHeld {
                lines.append("- [\(item.town)] \(item.story.title)\(item.story.summary.map { ": " + $0 } ?? "")")
            }
        }
        if !entries.isEmpty {
            lines.append("Organisations that match:")
            for item in entries {
                lines.append("- [\(item.town)] \(item.entry.name)\(item.entry.what.map { ": " + $0 } ?? "")")
            }
        }
        if stories.isEmpty && entries.isEmpty { lines.append("Nothing in the news matched what the reader said.") }
        return fit(lines) + "\n\nBrief the reader."
    }

    /// Keeps whole lines within the budget and says how many were left out.
    static func fit(_ lines: [String]) -> String {
        var out: [String] = []
        var used = 0
        for (index, line) in lines.enumerated() {
            if used + line.count + 1 > budget {
                out.append("(\(lines.count - index) more lines left out to fit the on-device model.)")
                break
            }
            out.append(line)
            used += line.count + 1
        }
        return out.joined(separator: "\n")
    }
}
