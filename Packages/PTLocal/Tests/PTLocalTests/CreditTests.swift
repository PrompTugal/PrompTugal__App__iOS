import Foundation
import Testing
@testable import PTLocal

private func tempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("credit-tests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private let offline: LocalFetch = { _ in throw URLError(.notConnectedToInternet) }

@MainActor
private func makeCredit(directory: URL = tempDirectory(), fetch: @escaping LocalFetch = offline) -> LocalCredit {
    LocalCredit(directory: directory, fetch: fetch, cache: LocalDiskCache(directory: directory.appendingPathComponent("cache")))
}

private let day: Double = 86_400

@Suite("Credit: pricing from the site's meter config")
struct CreditPricingTests {
    let config = MeterConfig.builtIn()!

    @Test("The built-in config is the site's: £5.00 start, GBP, floor 1p")
    func builtIn() {
        #expect(config.start == 500)
        #expect(config.currency == "GBP")
        #expect(config.symbol == "£")
        #expect(config.floor == 1)
        #expect(config.tiers.map(\.tier) == ["fresh", "new", "current", "archive"])
    }

    @Test("The formula gives every number in the site's own price table")
    func formulaMatchesTable() throws {
        for (type, kind) in config.types {
            if let base = config.prices[type] { #expect(base == kind.base, "\(type)") }
            guard kind.decays else { continue }
            for tier in config.tiers {
                let listed = try #require(config.prices["\(type)_\(tier.tier)"], "\(type)_\(tier.tier) missing")
                #expect(MeterConfig.computed(base: kind.base, multiplier: tier.multiplier, floor: config.floor) == listed,
                        "\(type)_\(tier.tier)")
            }
        }
    }

    @Test("Halves round up as JavaScript's Math.round does (company, new: 3 × 1.5 = 4.5 → 5p)")
    func roundsHalfUp() {
        #expect(MeterConfig.computed(base: 3, multiplier: 1.5, floor: 1) == 5)
        #expect(MeterConfig.computed(base: 1, multiplier: 0.5, floor: 1) == 1)   // the floor
        #expect(MeterConfig.computed(base: 0, multiplier: 2, floor: 1) == 0)     // the meter's own pages
    }

    @Test("Freshness tiers by age: fresh ≤ 1 day, new ≤ 7, current ≤ 30, then archive")
    func tiers() {
        #expect(config.tier(ageDays: 0)?.tier == "fresh")
        #expect(config.tier(ageDays: 1)?.tier == "fresh")
        #expect(config.tier(ageDays: 1.5)?.tier == "new")
        #expect(config.tier(ageDays: 7)?.tier == "new")
        #expect(config.tier(ageDays: 20)?.tier == "current")
        #expect(config.tier(ageDays: 400)?.tier == "archive")
        #expect(config.tier(ageDays: -3)?.tier == "fresh")       // dated in the future
        #expect(config.tier(ageDays: nil)?.tier == "current")    // no date: the base price
    }

    @Test("Prices by kind and age, as account/billing.md lists them")
    func prices() {
        #expect(config.price(type: "story", ageDays: 0.5) == 4)
        #expect(config.price(type: "story", ageDays: 3) == 3)
        #expect(config.price(type: "story", ageDays: 10) == 2)
        #expect(config.price(type: "story", ageDays: 90) == 1)
        #expect(config.price(type: "article", ageDays: 0) == 12)
        #expect(config.price(type: "article", ageDays: nil) == 6)
        #expect(config.price(type: "topic", ageDays: nil) == 3)
        #expect(config.price(type: "place", ageDays: 0) == 1)     // does not decay
        #expect(config.price(type: "place", ageDays: 900) == 1)
        #expect(config.price(type: "site", ageDays: nil) == 1)
        #expect(config.price(type: "account", ageDays: 0) == 0)
        #expect(config.price(type: "no-such-kind", ageDays: 0) == 1)   // the floor
    }

    @Test("The share read scales the price, never under a tenth")
    func depth() {
        #expect(config.price(type: "article", ageDays: nil, depth: 0.5) == 3)
        #expect(abs(config.price(type: "article", ageDays: nil, depth: 0) - 0.6) < 0.0001)
        #expect(config.price(type: "article", ageDays: nil, depth: 2) == 6)
    }

    @Test("A page's date: a bare day is midnight UTC; ISO times with and without seconds")
    func ages() throws {
        let now = try #require(MeterConfig.parseDate("2026-11-16T12:00:00Z"))
        #expect(MeterConfig.ageDays(of: "2026-11-15", now: now) == 1.5)
        #expect(MeterConfig.ageDays(of: "2026-11-16T00:00Z", now: now) == 0.5)
        #expect(MeterConfig.ageDays(of: "2026-11-16T06:00:00.000Z", now: now) == 0.25)
        #expect(MeterConfig.ageDays(of: nil, now: now) == nil)
        #expect(MeterConfig.ageDays(of: "not a date", now: now) == nil)
    }

    @Test("The fallback config prices as the built-in one")
    func fallback() {
        for type in config.types.keys {
            for age in [nil, 0, 3, 20, 100] as [Double?] {
                #expect(MeterConfig.fallback.price(type: type, ageDays: age) == config.price(type: type, ageDays: age), "\(type) \(String(describing: age))")
            }
        }
    }

    @Test("Money in the site's words")
    func money() {
        #expect(CreditMoney.money(5_000_000) == "£5.00")
        #expect(CreditMoney.money(4_960_000) == "£4.96")
        #expect(CreditMoney.money(-250_000) == "−£0.25")
        #expect(CreditMoney.money(6_000) == "£0.006")
        #expect(CreditMoney.price(0) == "free")
        #expect(CreditMoney.price(20_000) == "2p")
        #expect(CreditMoney.price(5_000) == "0.5p")
        #expect(CreditMoney.price(1_200_000) == "£1.20")
        #expect(CreditMoney.micro(pence: 500) == 5_000_000)
    }
}

@Suite("Credit: the ledger")
@MainActor
struct CreditLedgerTests {
    @Test("A new ledger starts with the site's starting balance")
    func starts() {
        let credit = makeCredit()
        #expect(credit.balance == 5_000_000)
        #expect(credit.balanceText == "£5.00")
        #expect(credit.history.count == 1)
        #expect(credit.history.first?.kind == .start)
    }

    @Test("Opening a town charges the site's place price, once per session")
    func town() {
        let credit = makeCredit()
        let faro = CreditKind.town(id: "faro", name: "Faro")
        #expect(credit.costText(of: faro) == "1p")
        #expect(credit.wouldCharge(faro))
        #expect(credit.charge(kind: faro))
        #expect(credit.balance == 5_000_000 - 10_000)
        #expect(!credit.charge(kind: faro))                  // the same page again this session
        #expect(credit.costText(of: faro) == "read")
        #expect(credit.balance == 4_990_000)
        credit.endSession()
        #expect(credit.charge(kind: faro))                   // a new session pays again, as on the site
        #expect(credit.balance == 4_980_000)
    }

    @Test("A story is priced by its freshness; the entry records type and tier")
    func story() throws {
        let credit = makeCredit()
        let now = try #require(MeterConfig.parseDate("2026-11-16T12:00:00Z"))
        let fresh = CreditKind.story(url: "https://example.org/a", title: "Fresh", date: "2026-11-16")
        let old = CreditKind.story(url: "https://example.org/b", title: "Old", date: "2026-08-01")
        #expect(credit.cost(of: fresh, now: now) == 40_000)
        #expect(credit.cost(of: old, now: now) == 10_000)
        credit.charge(kind: fresh, now: now)
        let entry = try #require(credit.history.first)
        #expect(entry.kind == .charge)
        #expect(entry.amount == -40_000)
        #expect(entry.pageType == "story")
        #expect(entry.tier == "fresh")
        #expect(entry.ref == "https://example.org/a")
    }

    @Test("Questions and contributions are charged every time; AI summaries once per thing")
    func repeats() {
        let credit = makeCredit()
        #expect(credit.charge(kind: .talk(to: "place.loule")))
        #expect(credit.charge(kind: .talk(to: "place.loule")))
        #expect(credit.charge(kind: .contribution("a photo")))
        #expect(credit.charge(kind: .contribution("a photo")))
        #expect(credit.charge(kind: .aiSummary(of: "faro", title: "Faro")))
        #expect(!credit.charge(kind: .aiSummary(of: "faro", title: "Faro")))
        #expect(credit.balance == 5_000_000 - 2 * 60_000 - 2 * 10_000 - 30_000)
    }

    @Test("Nothing is blocked: the balance goes below zero and charging goes on")
    func belowZero() {
        let credit = makeCredit()
        for index in 0..<90 { credit.charge(kind: .talk(to: "agent \(index)")) }
        #expect(credit.balance == 5_000_000 - 90 * 60_000)
        #expect(credit.isBelowZero)
        #expect(credit.charge(kind: .talk(to: "one more")))
        #expect(credit.book.addsUp)
    }

    @Test("The meter's own pages are free and write nothing")
    func free() {
        let credit = makeCredit()
        #expect(!credit.charge(kind: .page(type: "account", ref: "account", title: "Your account")))
        #expect(credit.costText(of: .page(type: "account", ref: "x", title: "x")) == "free")
        #expect(credit.history.count == 1)
    }

    @Test("A declined charge is given back once, with the reason")
    func decline() throws {
        let credit = makeCredit()
        credit.charge(kind: .talk(to: "faro"))
        let charge = try #require(credit.history.first)
        credit.decline(charge, reason: "It was a test")
        credit.decline(charge, reason: "again")
        #expect(credit.balance == 5_000_000)
        #expect(credit.isDeclined(charge))
        #expect(credit.history.filter { $0.kind == .refund }.count == 1)
        #expect(credit.book.spent == 0)
    }

    @Test("A top-up is credited once per App Store reference, and a test purchase says so")
    func topUps() throws {
        let credit = makeCredit()
        #expect(try credit.addTopUp(micro: 5_000_000, ref: "appstore-1", source: "appstore:xcode"))
        #expect(try !credit.addTopUp(micro: 5_000_000, ref: "appstore-1", source: "appstore:xcode"))
        #expect(credit.balance == 10_000_000)
        let entry = try #require(credit.history.first)
        #expect(entry.isTestPurchase)
        #expect(entry.text.contains("test purchase"))
        #expect(try credit.addTopUp(micro: 2_000, ref: "appstore-2", source: "appstore:production"))
        #expect(credit.history.first?.isTestPurchase == false)
        #expect(LocalTopUps.reference(for: 42) == "appstore-42")
        #expect(LocalTopUps.source(.sandbox) == "appstore:sandbox")
        #expect(LocalTopUps.StoreEnvironment.sandbox.isTest)
        #expect(!LocalTopUps.StoreEnvironment.production.isTest)
    }

    @Test("The ledger survives a relaunch; an unreadable file is kept aside")
    func persists() throws {
        let folder = tempDirectory()
        do {
            let credit = makeCredit(directory: folder)
            credit.charge(kind: .town(id: "faro", name: "Faro"))
        }
        let again = makeCredit(directory: folder)
        #expect(again.balance == 4_990_000)
        #expect(again.book.addsUp)

        try Data("not json".utf8).write(to: folder.appendingPathComponent("local-credit.json"))
        let fresh = makeCredit(directory: folder)
        #expect(fresh.balance == 5_000_000)
        #expect(fresh.problem != nil)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(files.contains { $0.contains("unreadable") })
    }

    @Test("Live prices replace the built-in ones; a bad file keeps them")
    func refresh() async throws {
        let live = try String(contentsOf: try #require(LocalResources.bundle.url(forResource: "billing-meter", withExtension: "json")), encoding: .utf8)
            .replacingOccurrences(of: "\"place\": 1,", with: "\"place\": 2,")
        let credit = makeCredit(fetch: { _ in Data(live.utf8) })
        #expect(credit.cost(of: .town(id: "faro", name: "Faro")) == 10_000)
        await credit.refreshPrices()
        #expect(credit.priceProvenance.isLive)
        #expect(credit.cost(of: .town(id: "faro", name: "Faro")) == 20_000)

        let broken = makeCredit(fetch: { _ in Data("{}".utf8) })
        await broken.refreshPrices()
        #expect(!broken.priceProvenance.isLive)
        #expect(broken.cost(of: .town(id: "faro", name: "Faro")) == 10_000)
    }

    @Test("The price list shows every app kind at the site's price")
    func priceList() {
        let credit = makeCredit()
        let prices = CreditKind.priceList.map { credit.cost(of: $0.kind) }
        #expect(prices == [40_000, 30_000, 20_000, 10_000, 30_000, 60_000, 10_000, 0])
    }

    @Test("The string hook (for PTPlaces' injected closure) maps to the same kinds and prices")
    func named() throws {
        let credit = makeCredit()
        let now = try #require(MeterConfig.parseDate("2026-11-16T12:00:00Z"))
        #expect(CreditKind.named("story", ref: "https://e.org/x", date: "2026-11-16", title: "X")
                == .story(url: "https://e.org/x", title: "X", date: "2026-11-16"))
        #expect(CreditKind.named("ai.summary", ref: "faro", title: "Faro") == .aiSummary(of: "faro", title: "Faro"))
        #expect(CreditKind.named("contribution", ref: "-", title: "a photo") == .contribution("a photo"))
        #expect(CreditKind.named("place", ref: "faro", title: "Faro").pageType == "place")
        #expect(credit.costText(action: "ai.summary", ref: "faro") == "3p")
        #expect(credit.charge(action: "story", ref: "https://e.org/x", date: "2026-11-16", title: "X"))
        #expect(!credit.charge(action: "story", ref: "https://e.org/x", date: "2026-11-16", title: "X"))
        #expect(credit.costText(action: "story", ref: "https://e.org/x") == "read")
        #expect(credit.cost(of: .named("story", ref: "y", date: "2026-11-16", title: "Y"), now: now) == 40_000)
    }
}
