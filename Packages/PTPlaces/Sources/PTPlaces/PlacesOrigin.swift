import Foundation
import PTCore
import SwiftUI

/// Where a screen's data came from, said in plain words (the app's rule: every screen says live, this device's copy
/// or the built-in snapshot, and data older than a day says its read date, never "live").
/// PTPlaces' own copy of the idea; PTLocal has its own label, and the two packages never import each other.
struct PlacesOrigin: Equatable {
    enum Kind: Equatable { case loading, live, dated, deviceCopy, snapshot, missing }

    let kind: Kind
    let text: String

    var warns: Bool { kind != .live && kind != .loading }

    var symbol: String {
        switch kind {
        case .loading: "arrow.triangle.2.circlepath"
        case .live: "dot.radiowaves.left.and.right"
        case .dated: "calendar"
        case .deviceCopy: "iphone"
        case .snapshot: "shippingbox"
        case .missing: "wifi.exclamationmark"
        }
    }

    /// - pinned: the value was put in by hand (previews, the built-in snapshot), never read from the network.
    /// - phase: the feed's phase; `.loaded` only after a good network read, so anything else with a value is the
    ///   copy saved on this device.
    /// - fetched: when the value was read (network or saved copy).
    /// - dataDate: the date the data itself carries ("2026-11-21" or an ISO time); a day counts until its end.
    static func describe(pinned: Bool, phase: LoadPhase, fetched: Date?, dataDate: String?, now: Date = .now) -> PlacesOrigin {
        if pinned {
            return PlacesOrigin(kind: .snapshot, text: String(localized: "Built-in snapshot, not live"))
        }
        guard let fetched else {
            if case .failed = phase {
                return PlacesOrigin(kind: .missing, text: String(localized: "Not loaded: promptugal.news could not be reached"))
            }
            return PlacesOrigin(kind: .loading, text: String(localized: "Reading promptugal.news"))
        }
        if phase != .loaded {
            return PlacesOrigin(kind: .deviceCopy, text: String(localized: "This device's copy, saved \(PlacesOrigin.day(fetched))"))
        }
        if let dataDate, let end = endOf(dataDate), now.timeIntervalSince(end) > 86_400 {
            return PlacesOrigin(kind: .dated, text: String(localized: "From promptugal.news, data dated \(PlaceDates.short(dataDate))"))
        }
        return PlacesOrigin(kind: .live, text: String(localized: "Live from promptugal.news"))
    }

    /// The moment a date stops being current: the end of its day for a bare day, the time itself otherwise.
    static func endOf(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.count > 10, let time = PlaceDates.parse(trimmed) { return time }
        guard let day = PlaceDates.parse(String(trimmed.prefix(10))) else { return nil }
        return day.addingTimeInterval(86_400)
    }

    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "Europe/Lisbon")
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: date)
    }
}

extension RemoteFeed {
    /// This feed's origin, with the date the data carries.
    func origin(dataDate: String?, now: Date = .now) -> PlacesOrigin {
        PlacesOrigin.describe(pinned: pinned, phase: phase, fetched: updated, dataDate: dataDate, now: now)
    }
}

/// One line under a section: where its data came from.
struct PlacesOriginLabel: View {
    let origin: PlacesOrigin

    var body: some View {
        HStack(spacing: 6) {
            if origin.kind == .loading { ProgressView().controlSize(.mini) }
            Image(systemName: origin.symbol)
            Text(origin.text)
        }
        .font(.caption)
        .foregroundStyle(origin.warns ? Palette.amber : Palette.muted)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("places.origin")
    }
}
