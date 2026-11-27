import Foundation

/// What the "My town" widget shows: the towns the person follows, each with its newest sourced story.
///
/// The app writes it to the App Group container whenever the followed towns or their news change; the widget reads
/// it and never touches the network. No story is invented: a town with no sourced story has `story == nil`.
public struct MyTownSnapshot: Codable, Sendable, Equatable {
    public struct Story: Codable, Sendable, Hashable {
        public var title: String
        /// "2026-11-26", as the site writes it.
        public var date: String
        /// The outlet that published it ("Sul Informação").
        public var outlet: String
        /// The source article (every story links to its source).
        public var url: URL

        public init(title: String, date: String, outlet: String, url: URL) {
            self.title = title
            self.date = date
            self.outlet = outlet
            self.url = url
        }
    }

    public struct Town: Codable, Sendable, Hashable, Identifiable {
        public var id: String
        public var name: String
        public var story: Story?

        public init(id: String, name: String, story: Story?) {
            self.id = id
            self.name = name
            self.story = story
        }
    }

    public static let version = 1

    public var version = MyTownSnapshot.version
    /// When the app wrote it.
    public var updatedAt: Date
    /// Where the data came from: "live", "cached" or "built-in" (every screen says which).
    public var origin: String
    /// In the order the person followed them.
    public var towns: [Town]

    public init(version: Int = MyTownSnapshot.version, updatedAt: Date, origin: String, towns: [Town]) {
        self.version = version
        self.updatedAt = updatedAt
        self.origin = origin
        self.towns = towns
    }
}

extension SharedContainer {
    public static let myTownKind = "news.promptugal.reader.my-town"
    private static let myTownFile = "my-town.json"

    public static func readMyTown() -> MyTownSnapshot? {
        guard let file = url?.appendingPathComponent(myTownFile),
              let data = try? Data(contentsOf: file) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(MyTownSnapshot.self, from: data),
              snapshot.version == MyTownSnapshot.version else { return nil }
        return snapshot
    }

    /// Returns false when there is no App Group container to write to.
    @discardableResult
    public static func writeMyTown(_ snapshot: MyTownSnapshot) throws -> Bool {
        guard let directory = url else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: directory.appendingPathComponent(myTownFile), options: .atomic)
        return true
    }
}
