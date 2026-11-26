import PTCore
import SwiftUI

/// A place page's layers from the public sites: what is on in the town (data.promptugal.news) and, for the 16
/// Algarve councils, the council's open notices (civic.promptugal.news). Each block opens its source and says when
/// its data was read; a block with nothing for this town is not shown. For PTPlaces' `.placeAccessory` hook.
public struct TownLayers: View {
    public let placeID: String
    @State private var store = TownLayersStore.shared

    public init(placeID: String) { self.placeID = placeID }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            if let layer = store.events[placeID] {
                TownEventsBlock(layer: layer, now: Date())
            }
            if let council = CivicCouncil.council(for: placeID) {
                CouncilNoticesBlock(council: council, notices: store.notices, file: store.councils[council], now: Date())
            }
        }
        .task(id: placeID) { await store.load(placeID: placeID) }
    }
}

/// What is on in the town, soonest first; hidden when nothing upcoming is listed.
struct TownEventsBlock: View {
    let layer: TownLayersStore.Layer<TownEventsFeed>
    let now: Date

    var body: some View {
        let upcoming = layer.value.upcoming(now: now)
        if !upcoming.isEmpty {
            TitledCard(LocalText.string("What is on"), kicker: LocalText.string("Events")) {
                ForEach(upcoming) { event in
                    if let link = event.link { EventRow(event: event, link: link) }
                }
                ProvenanceLabel(provenance: layer.provenance, phase: .idle, readAt: layer.value.readDate,
                                host: "data.promptugal.news")
                Text(LocalText.string("From the venues' and councils' own agendas, as data.promptugal.news reads them. A dated list, not a ticket office."))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct EventRow: View {
    let event: TownEventsFeed.Event
    let link: URL

    var body: some View {
        Link(destination: link) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(detail).font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(LocalText.string("Opens the event's source"))
    }

    private var detail: String {
        var parts: [String] = []
        if let start = event.startDate { parts.append(TownLayerDates.day(start)) }
        if let end = event.endDate, end != event.startDate { parts.append("to " + TownLayerDates.day(end)) }
        if let venue = event.venue { parts.append(venue) }
        if let host = link.host() { parts.append(host) }
        return parts.joined(separator: " · ")
    }
}

/// A council's procurement notices still open, each opening its notice in the Diário da República, and a line with
/// the council's contracts this year. Hidden when there is neither.
struct CouncilNoticesBlock: View {
    let council: String
    let notices: TownLayersStore.Layer<CivicNotices>?
    let file: TownLayersStore.Layer<CivicCouncil>?
    let now: Date

    var body: some View {
        let open = notices?.value.open(council: council, now: now) ?? []
        if !open.isEmpty || file != nil {
            TitledCard(title, kicker: LocalText.string("Council notices")) {
                if open.isEmpty {
                    Text(LocalText.string("No procurement notice of this council is open today.")).font(.footnote).foregroundStyle(Palette.muted)
                }
                ForEach(open) { notice in
                    if let link = notice.link { NoticeRow(notice: notice, link: link) }
                }
                if let layer = notices, !open.isEmpty {
                    ProvenanceLabel(provenance: layer.provenance, phase: .idle, readAt: layer.value.readDate,
                                    host: "civic.promptugal.news")
                }
                if let layer = file { councilLine(layer) }
                Text(LocalText.string("PrompTugal.news Civic is not a council or government site. Every figure links to its source."))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    private var title: String {
        let name = file?.value.name ?? PlaceDirectory.info(council)?.name ?? council
        return LocalText.string("\(name) council")
    }

    @ViewBuilder private func councilLine(_ file: TownLayersStore.Layer<CivicCouncil>) -> some View {
        if let contracts = file.value.contracts2026 {
            Text(contractsText(contracts, value: file.value.value2026)).font(.footnote).foregroundStyle(Palette.ink)
        }
        ProvenanceLabel(provenance: file.provenance, phase: .idle, readAt: file.value.readDate,
                        host: "civic.promptugal.news")
        if let page = file.value.pageURL {
            Link(destination: page) {
                Label(LocalText.string("The council on PrompTugal.news Civic"), systemImage: "arrow.up.right.square")
            }
            .font(.footnote)
        }
    }

    private func contractsText(_ contracts: Int, value: Double?) -> String {
        guard let value else { return LocalText.string("\(String(describing: contracts)) public contracts in 2026 on the Portal BASE.") }
        return LocalText.string("\(String(describing: contracts)) public contracts in 2026 on the Portal BASE, \(String(describing: TownLayerDates.euros(value))) in all.")
    }
}

struct NoticeRow: View {
    let notice: CivicNotices.Notice
    let link: URL

    var body: some View {
        Link(destination: link) {
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.what).font(.subheadline).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading).lineLimit(4)
                Text(detail).font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(LocalText.string("Opens the notice in the Diário da República"))
    }

    private var detail: String {
        var parts: [String] = [LocalText.string("Notice \(String(describing: notice.notice))")]
        if let deadline = notice.deadline { parts.append(LocalText.string("bids by ") + TownLayerDates.day(deadline)) }
        if let price = notice.basePriceEUR { parts.append(LocalText.string("base price ") + TownLayerDates.euros(price)) }
        return parts.joined(separator: " · ")
    }
}

/// Small formatting for the town layers, plain and testable.
enum TownLayerDates {
    /// "2026-11-25" → "25 Nov"; anything else as given.
    static func day(_ text: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "Europe/Lisbon")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: TownDay.prefix(text)) else { return text }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_GB")
        out.timeZone = TimeZone(identifier: "Europe/Lisbon")
        out.dateFormat = "d MMM"
        return out.string(from: date)
    }

    /// "€6,640,085" style, no cents.
    static func euros(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "€" + (formatter.string(from: NSNumber(value: value)) ?? String(Int(value)))
    }
}
