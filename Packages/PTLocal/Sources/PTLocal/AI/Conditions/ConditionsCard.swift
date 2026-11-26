import PTCore
import SwiftUI

/// "Conditions now" for one town, from IPMA: the Algarve's active warnings in their IPMA colour, the nearest
/// station's latest wind, temperature and rain, and today's forecast for the nearest forecast city. Reads again every
/// ten minutes while it is on screen. Usable on its own or in the Places reader's place accessory slot.
public struct ConditionsCard: View {
    public let placeID: String
    @State private var store = ConditionsStore.shared

    public init(placeID: String) { self.placeID = placeID }

    public var body: some View {
        // A town reads its own; the Algarve page reads Faro's (the region's warnings are the same); Portugal shows none,
        // since IPMA's Algarve warnings and stations would not be true for the whole country.
        if let town = placeID == PlaceDirectory.region.id ? PlaceDirectory.info("faro")
                      : PlaceDirectory.towns.first(where: { $0.id == placeID }) {
            content(store.conditions(for: town), regionWide: placeID == PlaceDirectory.region.id)
                .task(id: placeID) {
                    while !Task.isCancelled {
                        await store.refresh()
                        try? await Task.sleep(for: .seconds(ConditionsStore.interval))
                    }
                }
        }
    }

    @ViewBuilder
    private func content(_ c: TownConditions, regionWide: Bool) -> some View {
        TitledCard(LocalText.string("Conditions now"), kicker: regionWide ? LocalText.string("The Algarve · readings near Faro · IPMA") : "\(c.town.name) · IPMA") {
            if c.warnings.isEmpty && store.provenance != .none {
                Label(LocalText.string("No IPMA warnings above green for the Algarve."), systemImage: "checkmark.shield")
                    .font(.footnote).foregroundStyle(Palette.green)
            }
            ForEach(c.warnings) { warning in WarningBanner(warning: warning) }

            if let reading = c.reading {
                ReadingRow(reading: reading)
            } else if store.provenance == .none {
                HStack(spacing: Space.s) {
                    ProgressView().controlSize(.small)
                    Text(LocalText.string("Reading IPMA's stations…")).font(.footnote).foregroundStyle(Palette.muted)
                }
            } else {
                Text(LocalText.string("No IPMA station within 40 km of \(String(describing: c.town.name)) has a reading in the last three hours."))
                    .font(.footnote).foregroundStyle(Palette.muted)
            }

            if let day = c.today { ForecastRow(day: day, city: c.forecastCity, town: c.town) }

            HStack(spacing: 6) {
                if store.loading { ProgressView().controlSize(.mini) }
                Image(systemName: store.provenance.isLive ? "dot.radiowaves.left.and.right" : "wifi.slash")
                Text(store.provenance.label)
                if case .live(let date) = store.provenance {
                    Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                } else if case .cached(let date?) = store.provenance {
                    Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                }
                Spacer(minLength: Space.s)
                Link(destination: IPMA.page) { Label(LocalText.string("ipma.pt"), systemImage: "arrow.up.right").labelStyle(.titleAndIcon) }
            }
            .font(.caption)
            .foregroundStyle(store.provenance.isLive ? Palette.muted : Palette.amber)
            if let problem = store.problem {
                Text(problem).font(.caption2).foregroundStyle(Palette.amber)
            }
        }
    }
}

/// One IPMA warning, in its level's colour.
struct WarningBanner: View {
    let warning: IPMA.Warning

    private var colour: Color {
        switch warning.level {
        case .red: Color(red: 0.85, green: 0.1, blue: 0.1)
        case .orange: Color(red: 0.95, green: 0.5, blue: 0.0)
        case .yellow: Color(red: 0.95, green: 0.8, blue: 0.0)
        case .green: Palette.green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(colour)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalText.string("\(String(describing: warning.level.label)) warning: \(String(describing: warning.typeEnglish))"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(LocalText.string("IPMA: \(String(describing: warning.type))\(String(describing: window))")).font(.caption).foregroundStyle(Palette.muted)
                if !warning.text.isEmpty {
                    Text(warning.text).font(.caption).foregroundStyle(Palette.ink).italic()
                }
            }
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colour.opacity(0.16), in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Space.radius, style: .continuous).strokeBorder(colour.opacity(0.7), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private var window: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Lisbon")
        guard let start = warning.start, let end = warning.end else { return "" }
        return LocalText.string(" · \(String(describing: formatter.string(from: start))) to \(String(describing: formatter.string(from: end))) (Portugal time)")
    }
}

/// The nearest station's latest reading: a wind arrow pointing where the wind goes.
struct ReadingRow: View {
    let reading: IPMA.Reading

    var body: some View {
        let o = reading.observation
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .center, spacing: Space.l) {
                VStack(spacing: 2) {
                    Image(systemName: "location.north.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.blue)
                        .rotationEffect(.degrees(o.wind?.arrowDegrees ?? 0))
                        .opacity(o.wind == nil ? 0.3 : 1)
                    Text(o.windKmh.map { "\(Int($0.rounded())) km/h" } ?? "wind –").font(.caption.monospacedDigit())
                    Text(o.wind.map { LocalText.string("from \(String(describing: $0.label))") } ?? LocalText.string("calm or variable")).font(.caption2).foregroundStyle(Palette.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(windWords(o))
                metric(o.temperature.map { String(format: "%.1f°C", $0) }, label: LocalText.string("temperature"))
                metric(o.rainMm.map { String(format: "%.1f mm", $0) }, label: LocalText.string("rain, last hour"))
                metric(o.humidity.map { "\(Int($0.rounded()))%" }, label: LocalText.string("humidity"))
            }
            Text(LocalText.string("\(String(describing: reading.station.name)) station, \(String(describing: NearMe.text(distance: reading.distance))) away · read \(String(describing: reading.time.formatted(date: .omitted, time: .shortened)))"))
                .font(.caption2).foregroundStyle(Palette.muted)
        }
    }

    private func windWords(_ o: IPMA.Observation) -> String {
        guard let kmh = o.windKmh else { return LocalText.string("No wind reading") }
        let from = o.wind.map { " from " + $0.label } ?? ""
        return LocalText.string("Wind \(String(describing: Int(kmh.rounded()))) kilometres an hour") + from
    }

    private func metric(_ value: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value ?? "–").font(.system(.title3, design: .serif, weight: .bold).monospacedDigit()).foregroundStyle(Palette.ink)
            Text(label).font(.caption2).foregroundStyle(Palette.muted)
        }
    }
}

/// Today's forecast for the nearest IPMA forecast city, saying which city it is.
struct ForecastRow: View {
    let day: IPMA.Day
    let city: IPMA.ForecastCity
    let town: PlaceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary).font(.footnote).foregroundStyle(Palette.ink)
            Text(city.name == town.name ? LocalText.string("IPMA forecast for \(String(describing: city.name)), \(String(describing: day.forecastDate))")
                                        : LocalText.string("IPMA forecast for \(String(describing: city.name)), the nearest forecast point to \(String(describing: town.name)), \(String(describing: day.forecastDate))"))
                .font(.caption2).foregroundStyle(Palette.muted)
        }
    }

    private var summary: String {
        var parts: [String] = []
        if let weather = day.weather { parts.append(weather) }
        if let low = day.tMin, let high = day.tMax { parts.append("\(low)–\(high)°C") }
        if let rain = day.rainChance { parts.append(LocalText.string("rain \(String(describing: rain))%")) }
        if let dir = day.predWindDir {
            parts.append(LocalText.string("wind \(String(describing: day.windClass.map { $0 + " " } ?? ""))from \(String(describing: dir))"))
        }
        return parts.isEmpty ? LocalText.string("No forecast details.") : "Today: " + parts.joined(separator: ", ")
    }
}

/// One line of conditions for a town, for tight places (Near me): the worst active warning, else the latest
/// temperature and wind, with IPMA named as the source.
public struct ConditionsLine: View {
    public let placeID: String
    @State private var store = ConditionsStore.shared

    public init(placeID: String) { self.placeID = placeID }

    public var body: some View {
        if let town = PlaceDirectory.info(placeID) {
            let c = store.conditions(for: town)
            HStack(spacing: 6) {
                if let warning = c.warnings.first {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(warning.level == .yellow ? Palette.amber : Palette.red)
                    Text(LocalText.string("\(String(describing: warning.level.label)) warning: \(String(describing: warning.typeEnglish))")).fontWeight(.semibold)
                }
                if let o = c.reading?.observation {
                    if let t = o.temperature { Text(String(format: "%.0f°C", t)) }
                    if let kmh = o.windKmh {
                        Image(systemName: "location.north.fill").rotationEffect(.degrees(o.wind?.arrowDegrees ?? 0)).foregroundStyle(Palette.blue)
                        Text(LocalText.string("\(String(describing: Int(kmh.rounded()))) km/h"))
                    }
                }
                Text(LocalText.string("· IPMA")).foregroundStyle(Palette.muted)
            }
            .font(.caption)
            .foregroundStyle(Palette.ink)
            .task { await store.refresh() }
            .accessibilityElement(children: .combine)
        }
    }
}
