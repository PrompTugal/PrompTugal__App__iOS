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
        if let town = PlaceDirectory.info(placeID) ?? (placeID == PlaceDirectory.region.id ? PlaceDirectory.towns.first : nil) {
            content(store.conditions(for: town))
                .task(id: placeID) {
                    while !Task.isCancelled {
                        await store.refresh()
                        try? await Task.sleep(for: .seconds(ConditionsStore.interval))
                    }
                }
        }
    }

    @ViewBuilder
    private func content(_ c: TownConditions) -> some View {
        TitledCard("Conditions now", kicker: "\(c.town.name) · IPMA") {
            if c.warnings.isEmpty && store.provenance != .none {
                Label("No IPMA warnings above green for the Algarve.", systemImage: "checkmark.shield")
                    .font(.footnote).foregroundStyle(Palette.green)
            }
            ForEach(c.warnings) { warning in WarningBanner(warning: warning) }

            if let reading = c.reading {
                ReadingRow(reading: reading)
            } else if store.provenance == .none {
                HStack(spacing: Space.s) {
                    ProgressView().controlSize(.small)
                    Text("Reading IPMA's stations…").font(.footnote).foregroundStyle(Palette.muted)
                }
            } else {
                Text("No IPMA station within 40 km of \(c.town.name) has a reading in the last three hours.")
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
                Link(destination: IPMA.page) { Label("ipma.pt", systemImage: "arrow.up.right").labelStyle(.titleAndIcon) }
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
                Text("\(warning.level.label) warning: \(warning.typeEnglish)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text("IPMA: \(warning.type)\(window)").font(.caption).foregroundStyle(Palette.muted)
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
        return " · \(formatter.string(from: start)) to \(formatter.string(from: end)) (Portugal time)"
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
                    Text(o.wind.map { "from \($0.label)" } ?? "calm or variable").font(.caption2).foregroundStyle(Palette.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(windWords(o))
                metric(o.temperature.map { String(format: "%.1f°C", $0) }, label: "temperature")
                metric(o.rainMm.map { String(format: "%.1f mm", $0) }, label: "rain, last hour")
                metric(o.humidity.map { "\(Int($0.rounded()))%" }, label: "humidity")
            }
            Text("\(reading.station.name) station, \(NearMe.text(distance: reading.distance)) away · read \(reading.time.formatted(date: .omitted, time: .shortened))")
                .font(.caption2).foregroundStyle(Palette.muted)
        }
    }

    private func windWords(_ o: IPMA.Observation) -> String {
        guard let kmh = o.windKmh else { return "No wind reading" }
        let from = o.wind.map { " from " + $0.label } ?? ""
        return "Wind \(Int(kmh.rounded())) kilometres an hour" + from
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
            Text(city.name == town.name ? "IPMA forecast for \(city.name), \(day.forecastDate)"
                                        : "IPMA forecast for \(city.name), the nearest forecast point to \(town.name), \(day.forecastDate)")
                .font(.caption2).foregroundStyle(Palette.muted)
        }
    }

    private var summary: String {
        var parts: [String] = []
        if let weather = day.weather { parts.append(weather) }
        if let low = day.tMin, let high = day.tMax { parts.append("\(low)–\(high)°C") }
        if let rain = day.rainChance { parts.append("rain \(rain)%") }
        if let dir = day.predWindDir {
            parts.append("wind \(day.windClass.map { $0 + " " } ?? "")from \(dir)")
        }
        return parts.isEmpty ? "No forecast details." : "Today: " + parts.joined(separator: ", ")
    }
}
