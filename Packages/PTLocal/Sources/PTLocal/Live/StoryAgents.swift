import Foundation

/// "This story, these agents": which agents brought a story to PrompTugal.news. Read from the place files (each site
/// says which agent writes it, `by`, and each story when it was read) and the dashboard (agents whose own notes name
/// the story's town or publisher). Nothing is guessed beyond that, and the screen says how each link was found.
public enum StoryAgents {
    public struct Credit: Identifiable, Hashable, Sendable {
        public enum How: String, Sendable {
            /// The agent writes the site that carries the story.
            case wrote
            /// The agent's own notes on the dashboard name the story's town or publisher.
            case mentions
        }
        public var id: String { role + "|" + how.rawValue }
        public let role: String
        public let address: String
        public let how: How
        public let note: String
    }

    /// A site's newest stories first (by the date each story carries).
    public static func newest(_ site: PlaceSite, limit: Int) -> [PlaceSite.News] {
        let sorted = site.aiNews.sorted { a, b in (a.date ?? "") > (b.date ?? "") }
        return Array(sorted.prefix(limit))
    }

    public static func credits(for story: PlaceSite.News, places: [String: PlaceSite],
                               dashboard: NewsroomDashboard?) -> [Credit] {
        var out: [Credit] = []
        var seen = Set<String>()
        var towns: [String] = []
        for info in PlaceDirectory.all {
            guard let site = places[info.id], site.aiNews.contains(where: { $0.url == story.url }) else { continue }
            let address = site.by.isEmpty ? info.agent : site.by
            let role = String(address.split(separator: "@").first ?? "")
            guard seen.insert(role).inserted else { continue }
            if info.id != PlaceDirectory.region.id && info.id != PlaceDirectory.country.id { towns.append(info.name) }
            let page = info.id == PlaceDirectory.country.id ? "Portugal's page" : info.id == PlaceDirectory.region.id ? LocalText.string("the Algarve's page") : "\(info.name)'s site"
            let read = story.readOn.map { LocalText.string(", read on \(String(describing: $0))") } ?? ""
            out.append(Credit(role: role, address: address, how: .wrote, note: LocalText.string("Found and wrote it up for \(String(describing: page))\(String(describing: read))")))
        }
        guard let dashboard else { return out }
        let needles = (towns + [story.publisher].compactMap { $0 }).filter { $0.count >= 4 }
        for agent in dashboard.agents where !seen.contains(agent.role) && !agent.role.hasPrefix("place.") {
            let notes = ([agent.state].compactMap { $0 } + agent.done.suffix(6) + agent.next).joined(separator: " \n ")
            if let hit = needles.first(where: { notes.localizedStandardContains($0) }) {
                seen.insert(agent.role)
                out.append(Credit(role: agent.role, address: agent.agent, how: .mentions,
                                  note: LocalText.string("Its notes on the dashboard mention \(String(describing: hit))")))
            }
        }
        return out
    }
}
