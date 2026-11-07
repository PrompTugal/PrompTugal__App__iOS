import Foundation
import Observation

@MainActor @Observable
final class ReaderStore {
    private struct Cache: Codable {
        var agenda: [Event] = []
        var news: [Story] = []
        var details: [String: EventDetail] = [:]
        var agendaUpdated: Date?
        var newsUpdated: Date?
    }

    private var cache = Cache()
    private var bookmarks: [String: Event] = [:]
    private let directory: URL
    private(set) var agendaUnavailable = false
    private(set) var newsUnavailable = false
    private(set) var refreshing = false
    var storageMessage: String?

    var agenda: [Event] { cache.agenda }
    var news: [Story] { cache.news }
    var agendaUpdated: Date? { cache.agendaUpdated }
    var newsUpdated: Date? { cache.newsUpdated }
    var saved: [Event] { bookmarks.values.sorted(by: Event.earlier) }

    init() {
        directory = URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
        if let decoded: Cache = read("content.json") { cache = decoded }
        if let decoded: [String: Event] = read("saved.json") { bookmarks = decoded }
    }

    func event(id: String) -> Event? {
        agenda.first { $0.id == id } ?? bookmarks[id]
    }

    func isSaved(_ event: Event) -> Bool { bookmarks[event.id] != nil }
    func detail(for event: Event) -> EventDetail? { cache.details[event.id] }

    func toggleSaved(_ event: Event) {
        var updated = bookmarks
        if updated.removeValue(forKey: event.id) == nil {
            updated[event.id] = self.event(id: event.id) ?? event
        }
        do {
            try write(updated, to: "saved.json")
            bookmarks = updated
        } catch {
            storageMessage = "The change couldn’t be saved on this device. Please try again."
        }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        async let agenda: Void = refreshAgenda()
        async let news: Void = refreshNews()
        _ = await (agenda, news)
    }

    private func refreshAgenda() async {
        do {
            let events = try await FeedClient.agenda()
            try Task.checkCancellation()
            let updatedBookmarks = events.reduce(into: bookmarks) { saved, event in
                if saved[event.id] != nil { saved[event.id] = event }
            }
            if updatedBookmarks != bookmarks {
                do {
                    try write(updatedBookmarks, to: "saved.json")
                    bookmarks = updatedBookmarks
                } catch {
                    storageMessage = "Saved sessions couldn’t be updated on this device."
                }
            }
            cache.agenda = events
            cache.agendaUpdated = .now
            agendaUnavailable = false
            persistCache()
        } catch {
            if !Task.isCancelled { agendaUnavailable = true }
        }
    }

    private func refreshNews() async {
        do {
            let stories = try await FeedClient.news()
            try Task.checkCancellation()
            cache.news = stories
            cache.newsUpdated = .now
            newsUnavailable = false
            persistCache()
        } catch {
            if !Task.isCancelled { newsUnavailable = true }
        }
    }

    func refreshDetail(for event: Event) async {
        do {
            let detail = try await FeedClient.detail(for: event)
            try Task.checkCancellation()
            cache.details[event.id] = detail
            persistCache()
        } catch {
            // The event page remains available when the detail feed cannot be reached.
        }
    }

    private func persistCache() {
        do {
            try write(cache, to: "content.json")
        } catch {
            storageMessage = "The latest content couldn’t be stored for offline use."
        }
    }

    private func read<Value: Decodable>(_ name: String) -> Value? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func write<Value: Encodable>(_ value: Value, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
