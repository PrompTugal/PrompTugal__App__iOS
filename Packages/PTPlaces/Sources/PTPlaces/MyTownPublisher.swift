import Foundation
import WidgetKit
import PTNowNext

/// Writes the "My town" snapshot (the followed towns, each with its newest sourced story) to the App Group for the
/// widget, and asks WidgetKit to reload it when the snapshot changes. Nothing is made up: a town with no sourced
/// story is written without one, and the snapshot says whether its data was live, cached or the built-in copy.
@MainActor
public enum MyTownPublisher {
    private static var lastWritten: MyTownSnapshot?

    public static func publish(store: PlacesStore = .shared, now: Date = .now) {
        let ids = PlaceFollows.ids(UserDefaults.standard.string(forKey: PlaceFollows.key) ?? "")
        let towns: [MyTownSnapshot.Town] = ids.compactMap { id in
            guard let place = store.place(id) else { return nil }
            let story = store.file(id)?.newsNewestFirst.first.flatMap { item -> MyTownSnapshot.Story? in
                guard let link = item.sourceLink else { return nil }
                return .init(title: item.title, date: item.date, outlet: item.outlet, url: link)
            }
            return .init(id: id, name: place.name, story: story)
        }
        let snapshot = MyTownSnapshot(updatedAt: now, origin: origin(ids, store: store), towns: towns)
        guard snapshot.towns != lastWritten?.towns || snapshot.origin != lastWritten?.origin else { return }
        do {
            guard try SharedContainer.writeMyTown(snapshot) else { return }
            lastWritten = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: SharedContainer.myTownKind)
        } catch {
            // The widget keeps its last timeline; nothing for the person to do.
        }
    }

    /// "live" when every followed town's file came from the site in this run, "cached" when one came from the
    /// device's saved copy, "built-in" when one came only from the copy shipped with the app.
    static func origin(_ ids: [String], store: PlacesStore) -> String {
        var result = "live"
        for id in ids {
            guard let feed = store.files[id], feed.value != nil else {
                if store.file(id) != nil { return "built-in" }
                continue
            }
            if feed.failed || feed.updated == nil { result = "cached" }
        }
        return result
    }
}
