import Foundation

/// The website's reading meter config (sg-meter v1.5), as promptugal.news publishes it at
/// `api/v1/billing/meter.json` (made from the site's `data/billing/prices.json`). The app charges from this file, so a
/// page kind costs the same in the app as on the site. A copy is built into the app (`Resources/billing-meter.json`);
/// the live file replaces it when it can be read.
///
/// Amounts are in pence, as on the site. The formula (account/billing.md):
/// `price = max(floor, round(base[type] × freshness[tier]))`, then × the share of the page read (never under
/// `minDepth`). Types that do not decay cost their base at any age; a base of 0 (the meter's own pages) is free.
public struct MeterConfig: Decodable, Sendable, Equatable {
    public struct PageType: Decodable, Sendable, Equatable {
        /// The reference kind it is priced as (article, analysis, story, evidence, site, account).
        public let pricedAs: String?
        public let base: Double
        public let decays: Bool

        enum CodingKeys: String, CodingKey { case pricedAs = "as", base, decays }

        public init(pricedAs: String?, base: Double, decays: Bool) {
            self.pricedAs = pricedAs
            self.base = base
            self.decays = decays
        }
    }

    public struct Tier: Decodable, Sendable, Equatable {
        public let tier: String
        /// Up to this many days old; nil for the last tier (the archive).
        public let maxDays: Double?
        public let multiplier: Double

        enum CodingKeys: String, CodingKey { case tier, maxDays = "max_days", multiplier }

        public init(tier: String, maxDays: Double?, multiplier: Double) {
            self.tier = tier
            self.maxDays = maxDays
            self.multiplier = multiplier
        }
    }

    public struct TopUp: Decodable, Sendable, Equatable {
        public let amount: Double?
    }

    public let meter: String?
    public let version: String?
    /// The starting balance, in pence (500 = £5.00).
    public let start: Double
    public let symbol: String
    public let currency: String
    public let minDepth: Double
    public let floor: Double
    /// The precomputed table: `type` and `type_tier` → pence. The site's meter reads the same numbers.
    public let prices: [String: Double]
    public let types: [String: PageType]
    public let tiers: [Tier]
    public let topup: TopUp?

    enum CodingKeys: String, CodingKey {
        case meter, version, start, symbol, currency, minDepth, floor, prices, types, tiers, topup
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meter = try? c.decode(String.self, forKey: .meter)
        version = try? c.decode(String.self, forKey: .version)
        start = try c.decode(Double.self, forKey: .start)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? "£"
        currency = (try? c.decode(String.self, forKey: .currency)) ?? "GBP"
        minDepth = (try? c.decode(Double.self, forKey: .minDepth)) ?? 0.1
        floor = (try? c.decode(Double.self, forKey: .floor)) ?? 1
        prices = (try? c.decode([String: Double].self, forKey: .prices)) ?? [:]
        types = try c.decode([String: PageType].self, forKey: .types)
        tiers = (try? c.decode([Tier].self, forKey: .tiers)) ?? []
        topup = try? c.decode(TopUp.self, forKey: .topup)
    }

    public init(start: Double, symbol: String = "£", currency: String = "GBP", minDepth: Double = 0.1, floor: Double = 1,
                prices: [String: Double] = [:], types: [String: PageType], tiers: [Tier]) {
        meter = nil
        version = nil
        self.start = start
        self.symbol = symbol
        self.currency = currency
        self.minDepth = minDepth
        self.floor = floor
        self.prices = prices
        self.types = types
        self.tiers = tiers
        topup = nil
    }

    // MARK: Freshness

    /// The tier for a page this many days old. A page with no date, or dated in the future, is priced as the site
    /// prices it: no date means the base price (the tier with multiplier 1), the future means fresh.
    public func tier(ageDays: Double?) -> Tier? {
        guard let ageDays else { return tiers.first { $0.multiplier == 1 } }
        let age = max(0, ageDays)
        return tiers.first { $0.maxDays == nil || age <= $0.maxDays! } ?? tiers.last
    }

    /// Days between a page's own date (`page-date`: "2026-11-15" or an ISO 8601 time) and now. A bare day is
    /// midnight UTC, as `Date.parse` reads it in the reader's browser.
    public static func ageDays(of pageDate: String?, now: Date = .now) -> Double? {
        guard let date = parseDate(pageDate) else { return nil }
        return now.timeIntervalSince(date) / 86_400
    }

    static func parseDate(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        // "2026-11-15T23:40Z" (no seconds), as some of the site's files write it.
        let short = DateFormatter()
        short.locale = Locale(identifier: "en_US_POSIX")
        short.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mmX", "yyyy-MM-dd"] {
            short.dateFormat = format
            if let date = short.date(from: String(text.prefix(format == "yyyy-MM-dd" ? 10 : text.count))) { return date }
        }
        return nil
    }

    // MARK: Price

    /// What a page of this type and age costs read to the end, in pence. Reads the site's own table first; works it
    /// out from the formula only for a pair the table does not list. An unknown type is priced at the floor, as the
    /// site's meter prices a page with no kind.
    public func price(type: String, ageDays: Double?) -> Double {
        guard let kind = types[type] else { return prices[type] ?? floor }
        if kind.base <= 0 { return 0 }
        guard kind.decays, let tier = tier(ageDays: ageDays) else { return prices[type] ?? max(floor, kind.base) }
        if let listed = prices["\(type)_\(tier.tier)"] { return listed }
        return Self.computed(base: kind.base, multiplier: tier.multiplier, floor: floor)
    }

    /// The formula alone: `max(floor, round(base × multiplier))`. JavaScript's `Math.round` rounds halves up; for
    /// the positive amounts here Swift's default rounding gives the same answer (4.5 → 5).
    public static func computed(base: Double, multiplier: Double, floor: Double) -> Double {
        guard base > 0 else { return 0 }
        return max(floor, (base * multiplier).rounded(.toNearestOrAwayFromZero))
    }

    /// The price times the share of the page read, never under `minDepth`.
    public func price(type: String, ageDays: Double?, depth: Double) -> Double {
        price(type: type, ageDays: ageDays) * min(1, max(minDepth, depth))
    }

    // MARK: The built-in copy

    public static func builtIn(bundle: Bundle = LocalResources.bundle) -> MeterConfig? {
        guard let url = bundle.url(forResource: "billing-meter", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MeterConfig.self, from: data)
    }

    /// The last resort if the built-in file cannot be read: the site's figures of v0.1.1514.
    public static let fallback = MeterConfig(
        start: 500,
        types: [
            "article": .init(pricedAs: "article", base: 6, decays: true),
            "company": .init(pricedAs: "analysis", base: 3, decays: true),
            "topic": .init(pricedAs: "analysis", base: 3, decays: true),
            "story": .init(pricedAs: "story", base: 2, decays: true),
            "event": .init(pricedAs: "story", base: 2, decays: true),
            "index": .init(pricedAs: "story", base: 2, decays: true),
            "person": .init(pricedAs: "evidence", base: 1, decays: false),
            "organisation": .init(pricedAs: "evidence", base: 1, decays: false),
            "place": .init(pricedAs: "evidence", base: 1, decays: false),
            "evidence": .init(pricedAs: "evidence", base: 1, decays: false),
            "data": .init(pricedAs: "evidence", base: 1, decays: false),
            "site": .init(pricedAs: "site", base: 1, decays: false),
            "account": .init(pricedAs: "account", base: 0, decays: false),
        ],
        tiers: [
            .init(tier: "fresh", maxDays: 1, multiplier: 2),
            .init(tier: "new", maxDays: 7, multiplier: 1.5),
            .init(tier: "current", maxDays: 30, multiplier: 1),
            .init(tier: "archive", maxDays: nil, multiplier: 0.5),
        ])
}
