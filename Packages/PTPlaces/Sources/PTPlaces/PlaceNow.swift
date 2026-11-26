import Foundation
import PTCore
import SwiftUI

// Now in this place (Dinis, 16 Nov ~10:40: the live data from public sources is "ridiculously powerful"):
// https://promptugal.news/api/v1/by-place/<id>/now.json, refreshed hourly: IPMA's nearest station, today's forecast,
// warnings, fire risk, UV, the sea, and flights near Faro. Shown big on each place. A tap opens a human page
// (the block's `page`, else IPMA's site), never a raw JSON.

public struct PlaceNow: Decodable, Sendable, Equatable {
    /// The airport named when now.json does not name one.
    static let defaultAirport = "Faro"

    /// IPMA's warning colours in the app's language; anything else as written.
    static func levelName(_ level: String) -> String {
        switch level.lowercased() {
        case "yellow": String(localized: "Yellow", bundle: .module)
        case "orange": String(localized: "Orange", bundle: .module)
        case "red": String(localized: "Red", bundle: .module)
        default: level.capitalized
        }
    }

    public var readAt: String
    public var station: Station?
    public var today: Day?
    public var warnings: [Warning]
    public var fireRisk: String?
    public var uv: Int?
    public var sea: Sea?
    public var flights: Int?
    public var airportName: String?
    /// Human pages per block, when the file gives them.
    public var pages: [String: String]

    public struct Station: Decodable, Sendable, Equatable {
        public var name: String
        public var km: Double?
        public var tempC: Double?
        public var humidityPct: Double?
        public var windKmh: Double?
        public var rainMm: Double?
    }

    public struct Day: Decodable, Sendable, Equatable {
        public var date: String
        public var minC: Double?
        public var maxC: Double?
        public var rainPct: Double?
    }

    public struct Warning: Decodable, Sendable, Equatable, Hashable {
        public var type: String
        public var level: String
        public var start: String
        public var end: String
    }

    public struct Sea: Decodable, Sendable, Equatable {
        public var wavesMaxM: Double?
        public var seaTempMaxC: Double?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        readAt = c.string("read_at") ?? ""
        var pages: [String: String] = [:]
        func page(_ key: String, _ block: KeyedDecodingContainer<AnyKey>?) {
            if let p = block?.string("page"), p.hasPrefix("https://") { pages[key] = p }
        }
        let st = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("station"))
        page("station", st)
        if let st {
            let reading = try? st.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("reading"))
            station = Station(name: st.string("name") ?? "", km: st.lenient(Double.self, "km"),
                              tempC: reading?.lenient(Double.self, "temp_c"), humidityPct: reading?.lenient(Double.self, "humidity_pct"),
                              windKmh: reading?.lenient(Double.self, "wind_kmh"), rainMm: reading?.lenient(Double.self, "rain_mm"))
        }
        let fc = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("forecast"))
        page("forecast", fc)
        if let fc, var days = try? fc.nestedUnkeyedContainer(forKey: AnyKey("days")), !days.isAtEnd,
           let first = try? days.nestedContainer(keyedBy: AnyKey.self) {
            today = Day(date: first.string("date") ?? "", minC: first.lenient(Double.self, "t_min_c"),
                        maxC: first.lenient(Double.self, "t_max_c"), rainPct: first.lenient(Double.self, "rain_prob_pct"))
        }
        let wa = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("warnings"))
        page("warnings", wa)
        var found: [Warning] = []
        if let wa, var list = try? wa.nestedUnkeyedContainer(forKey: AnyKey("active")) {
            while !list.isAtEnd {
                guard let w = try? list.nestedContainer(keyedBy: AnyKey.self) else { _ = try? list.decode(AnyDecodable.self); continue }
                found.append(Warning(type: w.string("type") ?? "", level: w.string("level") ?? "", start: w.string("start") ?? "", end: w.string("end") ?? ""))
            }
        }
        warnings = found.filter { $0.level != "green" }
        let fr = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("fire_risk"))
        page("fire_risk", fr)
        if let fr, var days = try? fr.nestedUnkeyedContainer(forKey: AnyKey("days")), !days.isAtEnd,
           let first = try? days.nestedContainer(keyedBy: AnyKey.self) {
            fireRisk = first.string("level")
        }
        let uvc = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("uv"))
        uv = uvc?.int("index")
        let se = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("sea"))
        page("sea", se)
        if let se { sea = Sea(wavesMaxM: se.lenient(Double.self, "waves_max_m"), seaTempMaxC: se.lenient(Double.self, "sea_temp_max_c")) }
        let ap = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("airport"))
        page("airport", ap)
        if let ap {
            airportName = ap.string("name")
            if var list = try? ap.nestedUnkeyedContainer(forKey: AnyKey("airline")) {
                var n = 0
                while !list.isAtEnd { _ = try? list.decode(AnyDecodable.self); n += 1 }
                flights = n
            }
        }
        self.pages = pages
    }

    public var isEmpty: Bool { station == nil && today == nil && warnings.isEmpty && sea == nil && flights == nil }
}

/// Skips one JSON value of any shape.
private struct AnyDecodable: Decodable {
    init(from decoder: Decoder) throws {
        if var a = try? decoder.unkeyedContainer() { while !a.isAtEnd { _ = try? a.decode(AnyDecodable.self) } }
    }
}

/// The big "Now in <place>" panel under each place's hero.
struct PlaceNowCard: View {
    let now: PlaceNow
    let placeName: String
    let accent: Color
    @Environment(\.openURL) private var openURL
    static let ipma = URL(string: "https://www.ipma.pt/en/index.html")!

    private func open(_ block: String) {
        openURL(now.pages[block].flatMap(URL.init(string:)) ?? Self.ipma)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Kicker(text: String(localized: "Now in \(placeName)", bundle: .module), color: accent)
                Spacer()
                if !now.readAt.isEmpty {
                    Text(String(localized: "read \(PlaceDates.ago(now.readAt))", bundle: .module)).font(.caption2).foregroundStyle(Palette.muted)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: Space.l) {
                if let t = now.station?.tempC {
                    Button { open("station") } label: {
                        Text("\(Int(t.rounded()))°").font(.system(size: 64, weight: .bold, design: .serif)).foregroundStyle(Palette.ink)
                    }
                    .buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let today = now.today, let lo = today.minC, let hi = today.maxC {
                        Text(String(localized: "Today \(Int(lo.rounded()))° to \(Int(hi.rounded()))°", bundle: .module)).font(.headline)
                    }
                    if let rain = now.today?.rainPct {
                        Text(String(localized: "\(Int(rain))% chance of rain", bundle: .module)).font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    if let st = now.station {
                        Text([st.name, st.km.map { String(localized: "\(Int($0)) km away", bundle: .module) } ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
            ForEach(now.warnings, id: \.self) { w in
                Button { open("warnings") } label: {
                    Label(String(localized: "\(PlaceNow.levelName(w.level)) warning: \(w.type)", bundle: .module), systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Self.warningColor(w.level).opacity(0.2), in: Capsule())
                        .foregroundStyle(Self.warningColor(w.level) == .yellow ? Palette.amber : Self.warningColor(w.level))
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Space.m)], alignment: .leading, spacing: Space.m) {
                if let h = now.station?.humidityPct { tile("humidity", "\(Int(h))%", String(localized: "humidity", bundle: .module), "station") }
                if let w = now.station?.windKmh { tile("wind", "\(Int(w.rounded())) km/h", String(localized: "wind", bundle: .module), "station") }
                if let f = now.fireRisk { tile("flame", f.capitalized, String(localized: "fire risk", bundle: .module), "fire_risk") }
                if let uv = now.uv { tile("sun.max", "\(uv)", String(localized: "UV index", bundle: .module), "station") }
                if let waves = now.sea?.wavesMaxM { tile("water.waves", String(format: "%.1f m", waves), String(localized: "waves", bundle: .module), "sea") }
                if let sea = now.sea?.seaTempMaxC { tile("thermometer.medium", "\(Int(sea.rounded()))°", String(localized: "sea", bundle: .module), "sea") }
                if let flights = now.flights { tile("airplane", "\(flights)", String(localized: "flights near \(now.airportName ?? PlaceNow.defaultAirport)", bundle: .module), "airport") }
            }
            Text(String(localized: "From IPMA's open data, read hourly. Not a warning service: follow IPMA and ANEPC.", bundle: .module))
                .font(.caption2).foregroundStyle(Palette.muted)
        }
        .padding(Space.l)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Space.radius))
        .overlay(RoundedRectangle(cornerRadius: Space.radius).stroke(accent.opacity(0.25), lineWidth: 1))
        .accessibilityIdentifier("places.now")
    }

    private func tile(_ symbol: String, _ value: String, _ label: String, _ block: String) -> some View {
        Button { open(block) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: symbol).foregroundStyle(accent)
                Text(value).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(label).font(.caption2).foregroundStyle(Palette.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    static func warningColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "red": .red
        case "orange": .orange
        default: .yellow
        }
    }
}
