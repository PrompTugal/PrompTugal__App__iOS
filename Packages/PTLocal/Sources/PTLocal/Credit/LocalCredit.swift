// The ledger file handling is adapted from VoiceDebrief (https://github.com/VoiceDebrief/VoiceDebrief__App__iOS),
// Apps/VoiceDebrief/Sources/Engine/CreditLedger.swift, Copyright the VoiceDebrief authors, Apache License 2.0.

import Foundation
import Observation
import PTCore

/// The news app's reading meter: the same prices as promptugal.news for the same kinds of reading, the same starting
/// balance, a history of charges on this device, and App Store top-ups (`LocalTopUps`).
///
/// The public hook for every screen that reads something paid:
///
/// ```swift
/// LocalCredit.shared.cost(of: .town(id: "faro", name: "Faro"))      // micro-credits, before anything is spent
/// LocalCredit.shared.costText(of: kind)                              // "1p", or "read" when already paid this session
/// LocalCredit.shared.charge(kind: .story(url: u, title: t, date: d)) // true when a charge was written
/// ```
///
/// As on the website, nothing is ever blocked: the balance may go below zero, and `charge` never refuses. Its result
/// says only whether a charge was written (false: free, or already paid for in this session). Do not gate content on
/// it.
///
/// The ledger is a file on this device and nothing checks it, as the site's meter lives in the browser's storage.
@MainActor @Observable
public final class LocalCredit {
    public static let shared: LocalCredit = LocalCredit()

    public private(set) var book: CreditBook
    public private(set) var config: MeterConfig
    /// Where the prices came from: live from promptugal.news, this device's last copy, or the copy built into the app.
    public private(set) var priceProvenance: Provenance
    /// Set when the ledger could not be read or written, in words for the credit screen.
    public private(set) var problem: String?
    /// What was charged (or seen free) in this app session: action + ref.
    public private(set) var paidThisSession: Set<String> = []
    /// The App Store top-ups.
    public let topUps: LocalTopUps

    @ObservationIgnored private let file: URL
    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cache: LocalDiskCache
    @ObservationIgnored private var started = false

    public nonisolated static let configURL = LocalStore.site.appendingPathComponent("api/v1/billing/meter.json")
    public nonisolated static let pricesPage = LocalStore.site.appendingPathComponent("account/billing.html")
    static let cacheKey = "billing-meter"

    public init(directory: URL? = nil, fetch: @escaping LocalFetch = LocalStore.liveFetch, cache: LocalDiskCache = .standard(),
                bundle: Bundle = LocalResources.bundle, now: Date = .now) {
        let folder = directory ?? URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
        let ledgerFile = folder.appendingPathComponent("local-credit.json")
        file = ledgerFile
        self.fetch = fetch
        self.cache = cache

        // Prices: this device's last live copy, else the copy built into the app. Locals first: with @Observable,
        // reading a stored property before every one is set is a use of `self`.
        let loaded: MeterConfig
        let provenance: Provenance
        if let data = cache.load(key: Self.cacheKey), let saved = try? JSONDecoder().decode(MeterConfig.self, from: data) {
            loaded = saved
            provenance = .cached(cache.modified(key: Self.cacheKey))
        } else if let built = MeterConfig.builtIn(bundle: bundle) {
            loaded = built
            provenance = .snapshot("prices " + (built.version ?? "in the app"))
        } else {
            loaded = .fallback
            provenance = .snapshot("prices v0.1.1514")
        }
        config = loaded
        priceProvenance = provenance

        var opened: CreditBook?
        var trouble: String?
        if let data = try? Data(contentsOf: ledgerFile) {
            opened = try? CreditBook.decode(data)
            if opened == nil {
                // A ledger that cannot be read is kept beside the new one, never overwritten.
                let aside = ledgerFile.deletingPathExtension().appendingPathExtension("unreadable-\(Int(now.timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: ledgerFile, to: aside)
                trouble = "The credit history on this device could not be read. It was kept as \(aside.lastPathComponent) and a new one started."
            }
        }
        // The site's starting balance (meter.json `start`, in pence), once, when this device's ledger is new.
        book = opened ?? CreditBook(startingCredit: CreditMoney.micro(pence: loaded.start), at: now)
        problem = trouble
        topUps = LocalTopUps()
        topUps.credit = self
        if opened == nil { write() }
    }

    /// Call once at launch: listens for App Store transactions finished elsewhere and reads the live prices.
    public static func start() {
        let credit = shared
        guard !credit.started else { return }
        credit.started = true
        credit.topUps.start()
        Task { await credit.refreshPrices() }
    }

    // MARK: Reading the balance

    public var balance: Int { book.balance }
    public var isBelowZero: Bool { book.balance < 0 }
    public var symbol: String { config.symbol }
    public var balanceText: String { CreditMoney.money(balance, symbol: symbol) }
    public var startingCredit: Int { CreditMoney.micro(pence: config.start) }
    /// Newest first, as the history lists them.
    public var history: [CreditEntry] { book.entries.reversed() }

    public func money(_ micro: Int) -> String { CreditMoney.money(micro, symbol: symbol) }

    // MARK: Prices, before anything is spent

    /// What this would cost now, read to the end, in micro-credits. 0 if it is free.
    public func cost(of kind: CreditKind, now: Date = .now) -> Int {
        CreditMoney.micro(pence: config.price(type: kind.pageType, ageDays: MeterConfig.ageDays(of: kind.pageDate, now: now)))
    }

    /// The freshness tier the price uses, or nil for a kind that does not decay.
    public func tier(of kind: CreditKind, now: Date = .now) -> String? {
        guard config.types[kind.pageType]?.decays == true else { return nil }
        return config.tier(ageDays: MeterConfig.ageDays(of: kind.pageDate, now: now))?.tier
    }

    /// True when charging this now would write a charge: it costs something and was not already paid this session.
    public func wouldCharge(_ kind: CreditKind, now: Date = .now) -> Bool {
        !(kind.oncePerSession && paidThisSession.contains(kind.id)) && cost(of: kind, now: now) > 0
    }

    /// "2p", "free", or "read" when it was already paid for in this session.
    public func costText(of kind: CreditKind, now: Date = .now) -> String {
        if kind.oncePerSession && paidThisSession.contains(kind.id) { return "read" }
        return CreditMoney.price(cost(of: kind, now: now), symbol: symbol)
    }

    // MARK: Charging

    /// Charges for something just read or done. Never refuses and never blocks: the balance may go below zero.
    /// Returns true if a charge was written; false if it was free or already paid for in this session.
    @discardableResult
    public func charge(kind: CreditKind, now: Date = .now) -> Bool {
        if kind.oncePerSession {
            guard !paidThisSession.contains(kind.id) else { return false }
            paidThisSession.insert(kind.id)
        }
        let cost = cost(of: kind, now: now)
        guard book.charge(kind, cost: cost, tier: tier(of: kind, now: now), at: now) != nil else { return false }
        write()
        return true
    }

    /// The closure shape for packages that do not import PTLocal (PTPlaces): plain strings in, as
    /// `CreditKind.named`. The app shell injects it, e.g.
    /// `PlacesCredit.charge = { LocalCredit.shared.charge(action: $0, ref: $1, date: $2, title: $3) }`.
    @discardableResult
    public func charge(action: String, ref: String, date: String? = nil, title: String) -> Bool {
        charge(kind: .named(action, ref: ref, date: date, title: title))
    }

    /// The same, for the price shown before spending: "2p", "free", or "read" when already paid this session.
    public func costText(action: String, ref: String, date: String? = nil) -> String {
        costText(of: .named(action, ref: ref, date: date, title: ""))
    }

    /// Gives a charge back, with the reason (the site's "Don't charge me").
    public func decline(_ entry: CreditEntry, reason: String) {
        if book.decline(entry.id, reason: reason) != nil { write() }
    }

    public func isDeclined(_ entry: CreditEntry) -> Bool { book.isDeclined(entry) }

    // MARK: Top-ups (from LocalTopUps)

    /// Records paid credit, saved before it returns. False if this reference was credited before.
    /// Throws when it cannot be saved: the caller must then not finish the App Store transaction.
    @discardableResult
    func addTopUp(micro: Int, ref: String, source: String) throws -> Bool {
        guard !book.hasTopUp(ref: ref) else { return false }
        let before = book
        guard book.topUp(micro, ref: ref, source: source) != nil else { return false }
        do {
            try save()
        } catch {
            book = before
            throw error
        }
        return true
    }

    // MARK: Prices from the site

    /// Reads the live meter config. Keeps the last good copy when the site cannot be read or the file is wrong.
    public func refreshPrices() async {
        do {
            let data = try await fetch(Self.configURL)
            let live = try JSONDecoder().decode(MeterConfig.self, from: data)
            guard !live.types.isEmpty else { return }
            config = live
            cache.store(data, key: Self.cacheKey)
            priceProvenance = .live(.now)
        } catch {
            if case .snapshot = priceProvenance { return }
            priceProvenance = .cached(cache.modified(key: Self.cacheKey))
        }
    }

    // MARK: The file

    private func write() {
        do {
            try save()
            problem = nil
        } catch {
            problem = "The credit history could not be saved on this device: \(error.localizedDescription)"
        }
    }

    private func save() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try book.encoded().write(to: file, options: [.atomic])
    }

    /// For tests: a fresh session (what was paid this session is forgotten).
    func endSession() { paidThisSession = [] }
}
