// Adapted from VoiceDebrief (https://github.com/VoiceDebrief/VoiceDebrief__App__iOS),
// Apps/VoiceDebrief/Sources/Model/Credit.swift, Copyright the VoiceDebrief authors, Apache License 2.0.
// Changes: pence prices from the website's meter config, page kinds and freshness tiers on each charge, the App Store
// environment on each top-up, public API for PTLocal.

import Foundation

/// Credit amounts. The unit is the micro-credit, one millionth of a pound, always a whole number, so a charge can be a
/// tenth of a penny (the site's minimum share of a page) without rounding. The site counts in pence.
public enum CreditMoney {
    public static let perPound = 1_000_000
    public static let perPenny = 10_000

    public static func micro(pence: Double) -> Int { Int((pence * Double(perPenny)).rounded()) }
    public static func pence(_ micro: Int) -> Double { Double(micro) / Double(perPenny) }

    /// "£4.96", "£4.962" when not a whole number of pence, or "−£0.25". Rounded to a tenth of a penny, as the site
    /// shows it.
    public static func money(_ micro: Int, symbol: String = "£") -> String {
        let tenths = (abs(micro) + 500) / 1_000
        let pounds = tenths / 1_000
        let rest = tenths % 1_000
        let digits = rest % 10 == 0 ? String(format: "%d.%02d", pounds, rest / 10) : String(format: "%d.%03d", pounds, rest)
        return (micro < 0 && tenths > 0 ? "−" : "") + symbol + digits
    }

    /// A price as a price list words it: "free", "3p", "0.5p" or "£1.20".
    public static func price(_ micro: Int, symbol: String = "£") -> String {
        if micro <= 0 { return "free" }
        if micro >= perPound { return money(micro, symbol: symbol) }
        let tenths = (micro + 500) / 1_000
        return tenths % 10 == 0 ? "\(tenths / 10)p" : "\(tenths / 10).\(tenths % 10)p"
    }
}

/// One line of the ledger. Entries are only ever added: a declined charge stays and a refund is written after it.
public struct CreditEntry: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case start
        case charge
        case topUp = "topup"
        case refund
    }

    public let id: String
    public let at: Date
    public let kind: Kind
    /// What was done, in words.
    public let text: String
    /// Signed micro-credits: a charge is negative; a top-up, a refund and the starting credit are positive.
    public let amount: Int
    /// The balance on this device after this entry.
    public let balance: Int
    /// The feature ("story", "town", "ai.summary"); never display text.
    public var action: String?
    /// The site's page-type the charge was priced as, and its freshness tier.
    public var pageType: String?
    public var tier: String?
    public var ref: String?
    /// Where a top-up came from: "appstore:xcode", "appstore:sandbox" or "appstore:production".
    public var source: String?
    /// Why a charge was declined.
    public var reason: String?
    /// The outlet whose story this was ("Barlavento", "PrompTugal.news"); nil for other things. Older ledgers have
    /// none. What an outlet's stories were worth is shown; payouts to outlets are planned, not yet made.
    public var outlet: String?

    /// True for a top-up that moved no money: Xcode's StoreKit test file or the App Store sandbox (TestFlight).
    public var isTestPurchase: Bool { kind == .topUp && source != "appstore:production" }
}

/// One outlet's line in "Where your credit goes".
public struct OutletLine: Identifiable, Equatable, Sendable {
    public let outlet: String
    /// Paid reads of its stories, and how many of those were declined.
    public var reads: Int
    public var declined: Int
    /// Micro-credits: what those reads were worth, less what was given back.
    public var worth: Int

    public var id: String { outlet }
}

/// The ledger as a value: this device's append-only log. The balance is the sum of the amounts.
public struct CreditBook: Codable, Equatable, Sendable {
    public static let version = 1

    /// Why a charge was declined, after the site's "Don't charge me".
    public static let declineReasons = [
        "It was not useful",
        "I opened it by mistake",
        "It was a test",
        "Another reason",
    ]

    public var v: Int
    public private(set) var entries: [CreditEntry]

    /// A new ledger, holding the site's starting credit as its first entry.
    public init(startingCredit: Int, at: Date = .now) {
        v = Self.version
        entries = []
        add(.start, text: "Starting credit (as on promptugal.news)", amount: startingCredit, at: at)
    }

    /// May be below zero: nothing is ever blocked.
    public var balance: Int { entries.reduce(0) { $0 + $1.amount } }
    /// Charged and not given back.
    public var spent: Int { -entries.filter { $0.kind == .charge || $0.kind == .refund }.reduce(0) { $0 + $1.amount } }
    public var toppedUp: Int { entries.filter { $0.kind == .topUp }.reduce(0) { $0 + $1.amount } }
    public var reads: Int { entries.filter { $0.kind == .charge }.count }

    /// True if every entry's recorded balance is the one before it plus its amount.
    public var addsUp: Bool {
        var running = 0
        for entry in entries {
            running += entry.amount
            if entry.balance != running { return false }
        }
        return true
    }

    /// Charges for something read or done. Writes nothing, and returns nil, if it costs nothing.
    @discardableResult
    public mutating func charge(_ kind: CreditKind, cost: Int, tier: String?, at: Date = .now) -> CreditEntry? {
        guard cost > 0 else { return nil }
        return add(.charge, text: kind.title, amount: -cost, at: at) {
            $0.action = kind.action
            $0.pageType = kind.pageType
            $0.tier = tier
            $0.ref = kind.ref
            $0.outlet = kind.outlet
        }
    }

    /// Adds paid credit. A payment reference is credited once, as the site does it.
    @discardableResult
    public mutating func topUp(_ amount: Int, ref: String, source: String, at: Date = .now) -> CreditEntry? {
        guard amount > 0, !ref.isEmpty, !hasTopUp(ref: ref) else { return nil }
        let test = source != "appstore:production"
        return add(.topUp, text: test ? "Top-up (test purchase, no money taken)" : "Top-up", amount: amount, at: at) {
            $0.ref = ref
            $0.source = source
        }
    }

    public func hasTopUp(ref: String) -> Bool { entries.contains { $0.kind == .topUp && $0.ref == ref } }

    public func isDeclined(_ entry: CreditEntry) -> Bool {
        entries.contains { $0.kind == .refund && $0.ref == entry.id }
    }

    /// Gives a charge back, with the reason. Once per charge.
    @discardableResult
    public mutating func decline(_ entryId: String, reason: String, at: Date = .now) -> CreditEntry? {
        guard let charge = entries.first(where: { $0.id == entryId }), charge.kind == .charge, !isDeclined(charge) else { return nil }
        return add(.refund, text: "Not charged: \(charge.text)", amount: -charge.amount, at: at) {
            $0.action = charge.action
            $0.pageType = charge.pageType
            $0.ref = charge.id
            $0.reason = reason
            $0.outlet = charge.outlet
        }
    }

    /// What your reading of each outlet's stories was worth on this device: paid reads less the ones declined. Most
    /// first. This is an attribution, not a payment: nothing is sent to any outlet yet.
    public func byOutlet() -> [OutletLine] {
        var lines: [String: OutletLine] = [:]
        for entry in entries {
            guard let outlet = entry.outlet, entry.kind == .charge || entry.kind == .refund else { continue }
            var line = lines[outlet] ?? OutletLine(outlet: outlet, reads: 0, declined: 0, worth: 0)
            if entry.kind == .charge {
                line.reads += 1
                line.worth += -entry.amount
            } else {
                line.declined += 1
                line.worth -= entry.amount
            }
            lines[outlet] = line
        }
        return lines.values.sorted { ($0.worth, $1.outlet) > ($1.worth, $0.outlet) }
    }

    @discardableResult
    private mutating func add(_ kind: CreditEntry.Kind, text: String, amount: Int, at: Date,
                              _ fill: (inout CreditEntry) -> Void = { _ in }) -> CreditEntry {
        var entry = CreditEntry(id: UUID().uuidString, at: at, kind: kind, text: text, amount: amount, balance: balance + amount)
        fill(&entry)
        entries.append(entry)
        return entry
    }

    // MARK: The file

    public static func decode(_ data: Data) throws -> CreditBook {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CreditBook.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
