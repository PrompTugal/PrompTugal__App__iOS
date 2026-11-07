import Foundation
import Observation

extension Notification.Name {
    /// Posted when App Store credit is waiting to be written into the website's meter.
    static let meterHasPendingCredit = Notification.Name("PrompTugal.meterHasPendingCredit")
}

/// The website's reading meter (`localStorage['web-summit.newsroom.meter.v1']` on promptugal.news, sg-meter v1.5,
/// state v3), shown natively. The balance lives in the page's storage, as on the web; the app reads a summary
/// through the bridge and writes App Store credit back through the website's own `credit()` rule.
///
/// State shape read from sg-meter-core.js: `{ v: 3, balance, spent, reads, declined, log[], topups[{ref, at,
/// credit, source}], sessions[ref], … }`. Amounts are in pence; the site's symbol is £ (api/v1/billing/meter.json).
@MainActor @Observable
final class MeterStore {
    struct Snapshot: Codable, Equatable, Sendable {
        var balance: Double
        var spent: Double
        var reads: Int
        var declined: Double
        var topups: Int
        var lastTopupReference: String?
        var readAt: Date
    }

    /// App Store credit not yet written into the page's meter. Kept until the page confirms it.
    struct PendingCredit: Codable, Identifiable, Hashable, Sendable {
        var id: String { reference }
        let reference: String       // "appstore-<transaction id>": the meter refuses a reference twice
        let pence: Int
        let productID: String
        let purchasedAt: Date
    }

    private struct Persisted: Codable {
        var snapshot: Snapshot?
        var pending: [PendingCredit] = []
        var credited: [PendingCredit] = []
    }

    private(set) var snapshot: Snapshot?
    private(set) var pendingCredits: [PendingCredit] = []
    private(set) var credited: [PendingCredit] = []

    @ObservationIgnored private let url: URL
    static let symbol = "£"

    init(directory: URL? = nil) {
        let folder = directory ?? URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
        url = folder.appendingPathComponent("meter.json")
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Persisted.self, from: data) {
            snapshot = saved.snapshot
            pendingCredits = saved.pending
            credited = saved.credited
        }
    }

    /// From the bridge: the summary the page's storage holds, or nil when the page has no meter yet.
    func update(from summary: [String: Any]?) {
        guard let summary, let balance = (summary["balance"] as? NSNumber)?.doubleValue else { return }
        let last = summary["lastTopup"] as? [String: Any]
        snapshot = Snapshot(balance: balance,
                            spent: (summary["spent"] as? NSNumber)?.doubleValue ?? 0,
                            reads: (summary["reads"] as? NSNumber)?.intValue ?? 0,
                            declined: (summary["declined"] as? NSNumber)?.doubleValue ?? 0,
                            topups: (summary["topups"] as? NSNumber)?.intValue ?? 0,
                            lastTopupReference: last?["ref"] as? String,
                            readAt: .now)
        try? save()      // only the app's copy of the balance; the page keeps the real one
    }

    enum CreditResult: Equatable, Sendable {
        case added          // recorded and saved on the device
        case alreadyKnown   // this transaction was recorded before (pending or credited)
    }

    /// Records a verified App Store purchase and saves it before returning.
    /// Throws when it cannot be saved: the caller must then NOT finish the transaction, so StoreKit delivers it
    /// again on the next launch instead of the credit being lost (Q3).
    @discardableResult
    func addCredit(reference: String, pence: Int, productID: String) throws -> CreditResult {
        guard !pendingCredits.contains(where: { $0.reference == reference }),
              !credited.contains(where: { $0.reference == reference }) else { return .alreadyKnown }
        let credit = PendingCredit(reference: reference, pence: pence, productID: productID, purchasedAt: .now)
        pendingCredits.append(credit)
        do {
            try save()
        } catch {
            pendingCredits.removeAll { $0.reference == reference }
            throw error
        }
        NotificationCenter.default.post(name: .meterHasPendingCredit, object: self)
        return .added
    }

    /// The page confirmed the credit. If this save fails the credit stays pending and is offered to the page again,
    /// which refuses a reference it has seen, so nothing is credited twice.
    func markCredited(_ credit: PendingCredit) {
        pendingCredits.removeAll { $0.reference == credit.reference }
        if !credited.contains(credit) { credited.insert(credit, at: 0) }
        try? save()
    }

    static func money(_ pence: Double) -> String {
        let negative = pence < -0.004
        return "\(negative ? "−" : "")\(symbol)\(String(format: "%.2f", abs(pence) / 100))"
    }

    /// The balance the reader will see once pending credit reaches the page.
    var expectedBalance: Double? {
        guard let snapshot else { return nil }
        return snapshot.balance + Double(pendingCredits.reduce(0) { $0 + $1.pence })
    }

    func save() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Persisted(snapshot: snapshot, pending: pendingCredits, credited: credited))
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
