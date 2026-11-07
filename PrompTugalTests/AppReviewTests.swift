import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import PrompTugal

// App Review readiness, team session: the bridge's gate (S7, Q10), the checkout block (3.1.1), the meter and
// StoreKit (Q3, R5), reminders (Q6, Q10), the planner store (Q10) and TeamStore's requests (Q8).
// Each rule has a control next to it: the same input that is allowed, so a test cannot pass by refusing everything.

private func tempDir(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func lisbon(_ day: String, _ clock: String) -> Date { Lisbon.instant(day: day, clock: clock)! }

private func event(_ slug: String, _ time: String, day: String = "2026-11-10", place: String = "Stage 2") -> Event {
    Event(date: day, time: time, title: slug.replacingOccurrences(of: "-", with: " "), place: place, kind: "session",
          official: true, page: "events/\(slug)/index.html")
}

// MARK: - Bridge gate

@Suite("Bridge gate")
struct BridgeGateTests {
    private func gate(_ scheme: String = "https", host: String = "promptugal.news", port: Int = 0,
                      main: Bool = true, op: String = "schedule.get") -> AppBridge.Gate {
        AppBridge.gate(scheme: scheme, host: host, port: port, isMainFrame: main, op: op)
    }

    @Test func theRightPageMayCallEveryPublicOp() {
        for op in AppBridge.ops { #expect(gate(op: op) == .allowed, "\(op)") }
        #expect(gate(port: 443) == .allowed)
        #expect(gate(host: "PROMPTUGAL.NEWS") == .allowed)
    }

    @Test func wrongHostIsRefused() {
        #expect(gate(host: "evil.example") != .allowed)
        #expect(gate(host: "promptugal.news.evil.example") != .allowed)
        #expect(gate(host: "sub.promptugal.news") != .allowed)
    }

    @Test func iframeIsRefused() {
        #expect(gate(main: false) != .allowed)
    }

    @Test func plainHTTPIsRefused() {
        #expect(gate("http") != .allowed)
        #expect(gate("file", host: "") != .allowed)
    }

    @Test func aPortOtherThan443IsRefused() {
        #expect(gate(port: 8443) != .allowed)
        #expect(gate(port: 80) != .allowed)
    }

    @Test func anUnknownOpIsRefused() {
        #expect(gate(op: "vault.load") == .refused(reason: "unknown op", message: "Unknown op vault.load."))
        #expect(gate(op: "") != .allowed)
    }

    @Test func theScheduleAndMeterBelongToPromptugalNewsOnly() {
        for op in ["schedule.get", "schedule.set", "schedule.pageChanged", "meter.topup", "meter.pageChanged"] {
            #expect(gate(host: "web-summit.sgit.ai", op: op) != .allowed, "\(op)")
        }
        // control: the team site may still ask who I am and plan reminders
        #expect(gate(host: "web-summit.sgit.ai", op: "identity.get") == .allowed)
        #expect(gate(host: "web-summit.sgit.ai", op: "notify.plan") == .allowed)
    }
}

// MARK: - Checkout block (3.1.1)

@Suite("Checkout block")
struct CheckoutPolicyTests {
    @Test func everyStripeHostIsBlocked() throws {
        for text in ["https://buy.stripe.com/6oU", "https://checkout.stripe.com/c/pay/cs_1", "https://stripe.com/",
                     "https://js.stripe.com/v3", "https://m.stripe.network/inner.html", "https://BUY.STRIPE.COM/x"] {
            #expect(CheckoutPolicy.isBlocked(try #require(URL(string: text))), "\(text)")
        }
    }

    @Test func otherCheckoutsAndOurTopUpPageAreBlocked() throws {
        for text in ["https://www.paypal.com/checkoutnow", "https://buymeacoffee.com/x", "https://x.lemonsqueezy.com/buy",
                     "https://promptugal.news/account/top-up.html"] {
            #expect(CheckoutPolicy.isBlocked(try #require(URL(string: text))), "\(text)")
        }
    }

    @Test func ordinaryPagesAreNotBlocked() throws {
        for text in ["https://promptugal.news/account/index.html", "https://promptugal.news/events/x/index.html",
                     "https://web-summit.sgit.ai/", "https://notstripe.com/", "https://stripe.com.evil.example/"] {
            #expect(!CheckoutPolicy.isBlocked(try #require(URL(string: text))), "\(text)")
        }
    }

    @Test func releaseTopUpScriptOffersNoAppPurchase() {
        let release = BridgeScripts.hideWebTopUp(offerAppTopUp: false)
        let debug = BridgeScripts.hideWebTopUp(offerAppTopUp: true)
        #expect(release.contains("const offer = false"))
        #expect(debug.contains("const offer = true"))
        #expect(!release.contains("__OFFER__"))
        // both hide the website's Stripe top-up
        #expect(release.contains(#"a[href*="buy.stripe.com"]"#) && debug.contains(#"a[href*="buy.stripe.com"]"#))
    }
}

// MARK: - Meter (Q3)

@Suite("Meter store")
@MainActor
struct MeterStoreTests {
    @Test func aCreditIsSavedBeforeItCounts() throws {
        let dir = try tempDir("meter")
        let meter = MeterStore(directory: dir)
        #expect(try meter.addCredit(reference: "appstore-1", pence: 500, productID: "p") == .added)
        #expect(try meter.addCredit(reference: "appstore-1", pence: 500, productID: "p") == .alreadyKnown)
        // a new store reads it back from disk
        #expect(MeterStore(directory: dir).pendingCredits.map(\.reference) == ["appstore-1"])
    }

    @Test func aFailedSaveThrowsAndKeepsNothing() throws {
        // a file where the folder should be: every save fails
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("meter-blocked-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        let meter = MeterStore(directory: blocker)
        #expect(throws: (any Error).self) { try meter.addCredit(reference: "appstore-2", pence: 500, productID: "p") }
        #expect(meter.pendingCredits.isEmpty)
        // control: the same credit into a writable folder is added
        let ok = MeterStore(directory: try tempDir("meter-ok"))
        #expect(try ok.addCredit(reference: "appstore-2", pence: 500, productID: "p") == .added)
    }

    @Test func storeKitConfigAgreesWithWhatTheAppCredits() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PrompTugal/Store/PrompTugal.storekit")
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let products = try #require(json["products"] as? [[String: Any]])
        #expect(Set(products.compactMap { $0["productID"] as? String }) == Set(CreditStore.packs.map(\.id)))
        for pack in CreditStore.packs {
            let product = try #require(products.first { $0["productID"] as? String == pack.id })
            #expect(product["type"] as? String == "Consumable")
            let text = ((product["localizations"] as? [[String: Any]])?.first?["description"] as? String) ?? ""
            #expect(text.contains(MeterStore.money(Double(pack.pence))), "\(pack.id): \(text)")
        }
    }
}

// MARK: - StoreKit (Q3)

@Suite("StoreKit purchases", .serialized)
@MainActor
struct CreditStoreTests {
    /// Held for the whole test: a test session only answers StoreKit while it is alive.
    let session: SKTestSession

    init() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PrompTugal/Store/PrompTugal.storekit")
        session = try SKTestSession(contentsOf: file)
        session.disableDialogs = true
        session.clearTransactions()
    }

    private func unfinishedIDs() async -> Set<String> {
        var ids = Set<String>()
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { ids.insert(transaction.productID) }
        }
        return ids
    }

    private func finishAll() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { await transaction.finish() }
        }
    }

    @Test func productsLoadWithTheirStorePrice() async throws {
        let credits = CreditStore(meter: MeterStore(directory: try tempDir("sk-load")))
        await credits.loadProducts()
        #expect(credits.products.map(\.id).sorted() == CreditStore.packs.map(\.id).sorted())
        // the price the app shows is the store's, never a number of its own (R5)
        #expect(credits.products.allSatisfy { !$0.displayPrice.isEmpty })
    }

    @Test func aSavedCreditFinishesTheTransaction() async throws {
        await finishAll()
        let meter = MeterStore(directory: try tempDir("sk-ok"))
        let credits = CreditStore(meter: meter)
        await credits.loadProducts()
        let product = try #require(credits.products.first { $0.id == "news.promptugal.reader.credit.5" })
        await credits.purchase(product)
        #expect(credits.status == .purchased(500))
        #expect(meter.pendingCredits.count == 1)
        #expect(meter.pendingCredits.first?.reference.hasPrefix("appstore-") == true)
        #expect(!(await unfinishedIDs()).contains(product.id))
    }

    @Test func aFailedSaveLeavesTheTransactionForNextLaunch() async throws {
        await finishAll()
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("sk-blocked-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        let meter = MeterStore(directory: blocker)
        let credits = CreditStore(meter: meter)
        await credits.loadProducts()
        let product = try #require(credits.products.first { $0.id == "news.promptugal.reader.credit.20" })
        await credits.purchase(product)
        #expect(meter.pendingCredits.isEmpty)
        if case .failed = credits.status {} else { Issue.record("expected a failed status, got \(credits.status)") }
        // not finished: StoreKit offers it again, so the credit is not lost
        #expect(await unfinishedIDs().contains(product.id))
        await finishAll()
    }
}

// MARK: - Reminders (Q6, Q10)

@Suite("Reminder scheduler", .serialized)
@MainActor
struct ReminderSchedulerTests {
    private func defaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "reminders-\(UUID().uuidString)")!
        suite.set(true, forKey: "reminders.askedOnce")   // never show the system prompt in tests
        return suite
    }

    @Test func plansPicksAndStandupsWithSettings() async throws {
        let dir = try tempDir("rem")
        let now = lisbon("2026-11-10", "09:00")
        let schedule = ScheduleStore(directory: dir, clock: { now })
        schedule.updateEvents([event("keynote", "11:00-11:30"), event("panel", "15:00-15:40")])
        schedule.toggle("keynote"); schedule.toggle("panel")
        let team = TeamStore(directory: dir.appendingPathComponent("team"), fetch: { _ in throw URLError(.notConnectedToInternet) })
        let suite = defaults()
        let identity = TeamIdentityStore(defaults: suite)
        let reminders = ReminderScheduler(schedule: schedule, team: team, identity: identity, defaults: suite)
        #expect(reminders.leadMinutes == 10)

        await reminders.reschedule(now: now)
        #expect(reminders.planned.map(\.id) == ["pt.pick.keynote", "pt.pick.panel"])
        #expect(reminders.planned.first?.fire == lisbon("2026-11-10", "10:50"))

        reminders.leadMinutes = 30
        #expect(suite.integer(forKey: "reminders.leadMinutes") == 30)
        await reminders.reschedule(now: now)
        #expect(reminders.planned.first?.fire == lisbon("2026-11-10", "10:30"))

        reminders.picksOn = false
        await reminders.reschedule(now: now)
        #expect(reminders.planned.isEmpty)
    }

    @Test func aReminderOpensTheSessionInsideTheApp() throws {
        let pick = ReminderItem(id: "pt.pick.ai-doom-or-boom", kind: .pick, title: "x", body: "", fire: .now, start: .now,
                                url: URL(string: "https://promptugal.news/events/ai-doom-or-boom/index.html"))
        #expect(pick.appLink.absoluteString == "promptugal://open/team.schedule?session=ai-doom-or-boom")
        let standup = ReminderItem(id: "pt.standup.2026-11-10-1200", kind: .standup, title: "x", body: "", fire: .now,
                                   start: .now, url: URL(string: "https://web-summit.sgit.ai/meetings/2026-11-10-1200/silvio/index.html"))
        let link = try #require(URLComponents(url: standup.appLink, resolvingAgainstBaseURL: false))
        #expect(link.scheme == "promptugal" && link.host == "open" && link.path == "/team.schedule")
        #expect(link.queryItems?.first?.value == "https://web-summit.sgit.ai/meetings/2026-11-10-1200/silvio/index.html")
    }

    @Test func aTappedReminderWaitsUntilTheAppTakesIt() {
        let url = URL(string: "promptugal://open/team.schedule?session=x")!
        // hold, not receive: receive also notifies the hosted app, whose own scheduler takes the link at once
        ReminderInbox.hold(url)
        #expect(ReminderInbox.take() == url)
        #expect(ReminderInbox.take() == nil)       // taken once
    }
}

// MARK: - Planner store (Q10)

@Suite("Planner store", .serialized)
@MainActor
struct PlannerStoreTests {
    nonisolated private static func centre(_ id: String, _ name: String, sessions: [String]) -> Data {
        let list = sessions.map { #"{"id":"s","title":"\#($0)","day":"2026-11-10","time":"14:00-14:30"}"# }
            .joined(separator: ",")
        return Data(#"{"person":{"id":"\#(id)","name":"\#(name)"},"event":{"sessions":[\#(list)]}}"#.utf8)
    }

    @Test func proposesAcceptsAndShowsTeammates() async throws {
        let dir = try tempDir("planner")
        let schedule = ScheduleStore(directory: dir, clock: { lisbon("2026-11-10", "08:00") })
        let fetch: TeamStore.Fetch = { url in
            if url.path.contains("people/vicky/") { return Self.centre("vicky", "Vicky Wang", sessions: ["panel two"]) }
            if url.path.contains("people/silvio/") { return Self.centre("silvio", "Silvio Switha", sessions: ["panel one"]) }
            throw URLError(.fileDoesNotExist)
        }
        let team = TeamStore(directory: dir.appendingPathComponent("team"), fetch: fetch)
        let suite = UserDefaults(suiteName: "planner-\(UUID().uuidString)")!
        let identity = TeamIdentityStore(defaults: suite)
        let planner = PlannerStore(schedule: schedule, team: team, identity: identity)
        let agenda = [event("panel-one", "14:00-14:30", place: "Stage 2"), event("panel-two", "14:00-14:30", place: "Stage 3"),
                      event("keynote", "10:00-10:30", place: "Centre Stage")]
        planner.updateAgenda(agenda)
        schedule.updateEvents(agenda)
        planner.day = "2026-11-10"

        let first = planner.plan
        #expect(!first.proposals.isEmpty)
        #expect(first.fixed.isEmpty)

        await team.refreshCentre(for: "vicky")
        await team.refreshCentre(for: "silvio")
        #expect(planner.teammates(for: "panel-two") == ["Vicky"])
        #expect(planner.teammates(for: "keynote").isEmpty)

        // accepting a proposal picks it, and the cached plan sees the change
        let keynote = try #require(planner.plan.proposals.first { $0.item.eventID == "keynote" })
        planner.accept([keynote])
        #expect(schedule.isPicked("keynote"))
        #expect(planner.plan.fixed.map(\.eventID) == ["keynote"])
        #expect(!planner.plan.proposals.contains { $0.item.eventID == "keynote" })
    }

    @Test func theDayStartsOnASummitDay() throws {
        let dir = try tempDir("planner-day")
        let planner = PlannerStore(schedule: ScheduleStore(directory: dir),
                                   team: TeamStore(directory: dir.appendingPathComponent("t"), fetch: { _ in Data() }),
                                   identity: TeamIdentityStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        #expect(PlannerStore.summitDays.contains(planner.day))
        #expect(planner.days == PlannerStore.summitDays)      // no agenda yet
    }
}

// MARK: - TeamStore through HTTPClient (Q8)

@Suite("Team requests")
struct TeamRequestTests {
    @Test func everyTeamRequestHasALabelForDebugNetwork() {
        let base = TeamEndpoints.base
        #expect(TeamStore.label(for: base.appendingPathComponent("me.json")) == "team.me")
        #expect(TeamStore.label(for: base.appendingPathComponent("meetings/index.md")) == "team.meetings")
        #expect(TeamStore.label(for: base.appendingPathComponent("people/silvio/app/data.json")) == "team.data.silvio")
        #expect(TeamStore.label(for: base.appendingPathComponent("wakes/index.md")) == "team.wakes")
    }

    @Test func lisbonDayIsOneHelper() {
        #expect(Lisbon.day(lisbon("2026-11-10", "23:59")) == "2026-11-10")
        #expect(Lisbon.day(lisbon("2026-11-11", "00:00")) == "2026-11-11")
        // control: a UTC day boundary in summer, when Lisbon is UTC+1
        #expect(Lisbon.day(ScheduleTime.parse("2026-07-01T23:30:00Z")!) == "2026-07-02")
    }
}
