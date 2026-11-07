import Foundation
import Observation
import WebKit

/// The bridge between the websites and the app (contracts §4, brief 05).
///
/// - One message handler, `pt`, in its own content world, answering only the main frame of an allowed origin.
/// - `window.ptApp = { version, ops, call }` injected into the page at document start.
/// - Two-way schedule sync with promptugal.news by reading and writing `localStorage['nr.schedule.v1']` in the page's
///   world and firing the page's own `nr:schedule` event. No website change is needed.
/// - The reading meter read from the page, the Stripe top-up hidden, and App Store credit written back.
///
/// To use it, a web view's configuration goes through `configure(_:for:)`, the view is passed to `attach(_:)`, and
/// `pageDidFinish(_:)` is called from the navigation delegate's `didFinish`.
@MainActor @Observable
final class AppBridge: NSObject, WKScriptMessageHandlerWithReply {
    static let handlerName = "pt"
    static let world = WKContentWorld.world(name: "PrompTugalBridge")
    /// Phase-1 ops (contracts §4). Both sides ignore unknown ops.
    nonisolated static let ops = ["schedule.get", "schedule.set", "identity.get", "notify.plan", "meter.topup"]
    /// Ops the app's own bridge-world script sends; never listed to pages.
    nonisolated static let internalOps: Set<String> = ["schedule.pageChanged", "meter.pageChanged"]

    nonisolated static let scheduleHosts: Set<String> = ["promptugal.news"]
    nonisolated static let teamHosts: Set<String> = ["web-summit.sgit.ai"]
    nonisolated static var allowedHosts: Set<String> { scheduleHosts.union(teamHosts) }

    /// Set when a page asks for a top-up; the UI presents the native purchase sheet and clears it.
    var topUpRequested = false
    /// Set when a page asks for reminders (notify.plan) and permission was never asked: the UI shows a native alert,
    /// and only a tap on it shows the system prompt (S7).
    var remindersRequested = false
    private(set) var lastScheduleSync: Date?

    @ObservationIgnored let log: BridgeLog
    @ObservationIgnored private let schedule: ScheduleStore
    @ObservationIgnored private let meter: MeterStore
    @ObservationIgnored private let identity: TeamIdentityStore
    @ObservationIgnored private let reminders: ReminderScheduler
    @ObservationIgnored private let views = NSHashTable<WKWebView>.weakObjects()
    @ObservationIgnored private var pushing = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(log: BridgeLog, schedule: ScheduleStore, meter: MeterStore, identity: TeamIdentityStore,
         reminders: ReminderScheduler) {
        self.log = log
        self.schedule = schedule
        self.meter = meter
        self.identity = identity
        self.reminders = reminders
        super.init()
        observers.append(NotificationCenter.default.addObserver(forName: .scheduleDidChange, object: schedule,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleChangedNatively() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .meterHasPendingCredit, object: meter,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPendingCredits() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .teamIdentityDidChange, object: identity,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.identityChanged() }
        })
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // MARK: Setting up a web view

    /// Gives the configuration its own data store, the injected scripts and the `pt` handler.
    func configure(_ configuration: WKWebViewConfiguration, for site: URL) {
        let host = site.host?.lowercased() ?? ""
        configuration.websiteDataStore = SiteDataStores.store(for: site)
        guard Self.allowedHosts.contains(host) else { return }
        let controller = configuration.userContentController
        controller.addUserScript(WKUserScript(source: BridgeScripts.pageAPI(version: Self.appVersion, ops: Self.ops),
                                              injectionTime: .atDocumentStart, forMainFrameOnly: true,
                                              in: .page))
        controller.addUserScript(WKUserScript(source: BridgeScripts.bridgeWorld, injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true, in: Self.world))
        if Self.scheduleHosts.contains(host) {
            controller.addUserScript(WKUserScript(source: BridgeScripts.hideWebTopUp(offerAppTopUp: ReadingCredit.isAvailable),
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: true, in: .page))
        }
        controller.addScriptMessageHandler(self, contentWorld: Self.world, name: Self.handlerName)
        log.record(host: host, .app, op: "bridge.configure", detail: "store: \(SiteDataStores.defaultStoreHosts.contains(host) ? "default" : "own")")
    }

    func attach(_ webView: WKWebView) { views.add(webView) }

    /// Call from `webView(_:didFinish:)`: syncs the schedule, reads the meter, writes the team identity.
    func pageDidFinish(_ webView: WKWebView) {
        views.add(webView)
        guard let host = webView.url?.host?.lowercased() else { return }
        Task {
            if Self.scheduleHosts.contains(host) {
                await syncSchedule(with: webView)
                await readMeter(from: webView)
                await creditPending(in: webView)
            }
            if Self.teamHosts.contains(host) { await writeIdentity(to: webView) }
        }
    }

    /// Asks a navigation the app should handle itself. Returns true when the app took it (the caller cancels).
    /// Every web view asks this before a navigation (guideline 3.1.1): checkouts are never opened in the app.
    func handlesNavigation(to url: URL) -> Bool {
        guard CheckoutPolicy.isBlocked(url) else { return false }
        let host = url.host?.lowercased() ?? "?"
        if ReadingCredit.isAvailable {
            log.record(host: host, .app, op: "checkout.blocked", detail: "web checkout replaced by the native top-up")
            topUpRequested = true
        } else {
            log.record(host: host, .app, op: "checkout.blocked", detail: "web checkout blocked in the app")
        }
        return true
    }

    // MARK: Messages from pages

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) async -> (Any?, String?) {
        let started = Date()
        let origin = message.frameInfo.securityOrigin
        let host = origin.host.lowercased()
        let body = message.body as? [String: Any]
        let op = body?["op"] as? String ?? "?"
        let gate = Self.gate(scheme: origin.protocol, host: host, port: origin.port,
                             isMainFrame: message.frameInfo.isMainFrame, op: op)
        if case .refused(let reason, let text) = gate {
            log.record(host: host, .pageToApp, op: op, detail: reason, outcome: .refused)
            return (nil, text)
        }
        let args = body?["args"] as? [String: Any] ?? [:]
        do {
            let (result, detail) = try await handle(op: op, args: args, host: host, webView: message.webView)
            log.record(host: host, .pageToApp, op: op, detail: detail,
                       durationMs: Date().timeIntervalSince(started) * 1000)
            return (result, nil)
        } catch let error as BridgeError {
            log.record(host: host, .pageToApp, op: op, detail: error.message,
                       outcome: error.refused ? .refused : .failed)
            return (nil, error.message)
        } catch {
            log.record(host: host, .pageToApp, op: op, detail: error.localizedDescription, outcome: .failed)
            return (nil, "The app could not do that.")
        }
    }

    enum Gate: Equatable, Sendable {
        case allowed
        case refused(reason: String, message: String)
    }

    /// Who may call which op, decided before anything runs. Pure, so the rules are unit-tested (Q10):
    /// the main frame only, https only, the default port (0 or 443), an allowed host, a known op, and the op's own
    /// hosts (the schedule and the meter belong to promptugal.news only).
    nonisolated static func gate(scheme: String, host: String, port: Int, isMainFrame: Bool, op: String) -> Gate {
        let host = host.lowercased()
        let notAllowed = "This page may not use the app bridge."
        guard isMainFrame else { return .refused(reason: "not the main frame", message: notAllowed) }
        guard scheme == "https" else { return .refused(reason: "not https", message: notAllowed) }
        guard port == 0 || port == 443 else { return .refused(reason: "port \(port)", message: notAllowed) }
        guard allowedHosts.contains(host) else { return .refused(reason: "origin not allowed", message: notAllowed) }
        guard ops.contains(op) || internalOps.contains(op) else {
            return .refused(reason: "unknown op", message: "Unknown op \(op).")
        }
        if scheduleOnlyOps.contains(op), !scheduleHosts.contains(host) {
            return .refused(reason: "op not for this site", message: "Not on this site.")
        }
        return .allowed
    }

    /// Ops that read or change the schedule or the meter: promptugal.news only.
    nonisolated static let scheduleOnlyOps: Set<String> = ["schedule.get", "schedule.set", "schedule.pageChanged",
                                                           "meter.topup", "meter.pageChanged"]

    struct BridgeError: Error {
        let message: String
        var refused = false
    }

    private func handle(op: String, args: [String: Any], host: String,
                        webView: WKWebView?) async throws -> (Any?, String) {
        let scheduleSite = Self.scheduleHosts.contains(host)
        switch op {
        case "schedule.get":
            guard scheduleSite else { throw BridgeError(message: "Not on this site.", refused: true) }
            return (jsonObject(schedule.document.encoded()), "\(schedule.document.picks.count) picks")
        case "schedule.set":
            guard scheduleSite else { throw BridgeError(message: "Not on this site.", refused: true) }
            guard let data = try? JSONSerialization.data(withJSONObject: args),
                  let incoming = ScheduleDocument.decode(data) else {
                throw BridgeError(message: "Expected { v: 1, picks: [...] }.")
            }
            let outcome = schedule.merge(incoming, from: .web)
            if let webView { await pushSchedule(to: webView) }
            return (jsonObject(schedule.document.encoded()), "+\(outcome.added.count) −\(outcome.removed.count)")
        case "schedule.pageChanged":
            guard scheduleSite else { throw BridgeError(message: "Not on this site.", refused: true) }
            let raw = args["doc"] as? String ?? ""
            let incoming = ScheduleDocument.decode(raw) ?? ScheduleDocument()
            let outcome = schedule.merge(incoming, from: raw.isEmpty ? .vault : .web)
            if let webView, Set(incoming.picks.map(\.id)) != Set(schedule.document.picks.map(\.id)) {
                await pushSchedule(to: webView)
            }
            schedule.markSynced(.web, document: schedule.document)
            return (nil, "+\(outcome.added.count) −\(outcome.removed.count)")
        case "identity.get":
            guard let person = identity.current else { return (NSNull(), "no identity") }
            return (["id": person.id, "name": person.name, "verified": identity.verified] as [String: Any],
                    identity.verified ? "verified" : "chosen")
        case "notify.plan":
            // A page call is not a user gesture: never show the system prompt from here. If permission was never
            // asked, the app shows its own alert, and the prompt follows only a tap on it (S7).
            let status = await reminders.currentAuthorization()
            if status == .unknown { remindersRequested = true }
            var count = 0
            if status == .allowed { count = await reminders.reschedule() }
            return (["authorized": status == .allowed, "asked": status == .unknown, "scheduled": count] as [String: Any],
                    status == .unknown ? "native alert" : "\(count) reminders")
        case "meter.topup":
            guard scheduleSite else { throw BridgeError(message: "Not on this site.", refused: true) }
            guard ReadingCredit.isAvailable else { throw BridgeError(message: "Top-ups are not available in the app.") }
            topUpRequested = true
            return (["presented": true] as [String: Any], "native sheet")
        case "meter.pageChanged":
            guard scheduleSite else { throw BridgeError(message: "Not on this site.", refused: true) }
            meter.update(from: args["meter"] as? [String: Any])
            return (nil, meter.snapshot.map { "balance \($0.balance)p" } ?? "no meter")
        default:
            throw BridgeError(message: "Unknown op \(op).", refused: true)
        }
    }

    private func jsonObject(_ data: Data) -> Any {
        (try? JSONSerialization.jsonObject(with: data)) ?? NSNull()
    }

    // MARK: Schedule sync

    private func scheduleViews() -> [WKWebView] {
        views.allObjects.filter { Self.scheduleHosts.contains($0.url?.host?.lowercased() ?? "") }
    }

    /// Reads the page's picks, merges them, and writes the merged list back when the page lacks something.
    func syncSchedule(with webView: WKWebView) async {
        let started = Date()
        let raw: String?
        do {
            raw = try await webView.callAsyncJavaScript(BridgeScripts.readSchedule, arguments: [:], in: nil,
                                                        contentWorld: .page) as? String
        } catch {
            log.record(host: hostOf(webView), .appToPage, op: "schedule.read", detail: error.localizedDescription,
                       outcome: .failed)
            return
        }
        // A page with no schedule at all (new, or storage cleared by WebKit) removes nothing: plain union.
        let pageHasSchedule = !(raw ?? "").isEmpty
        let incoming = raw.flatMap(ScheduleDocument.decode) ?? ScheduleDocument()
        let outcome = schedule.merge(incoming, from: pageHasSchedule ? .web : .vault)
        log.record(host: hostOf(webView), .appToPage, op: "schedule.read",
                   detail: "\(incoming.picks.count) on page, +\(outcome.added.count) −\(outcome.removed.count)",
                   durationMs: Date().timeIntervalSince(started) * 1000)
        if Set(incoming.picks.map(\.id)) != Set(schedule.document.picks.map(\.id)) {
            await pushSchedule(to: webView)
        }
        schedule.markSynced(.web, document: schedule.document)
        lastScheduleSync = .now
    }

    func pushSchedule(to webView: WKWebView) async {
        let started = Date()
        let document = schedule.document
        do {
            let changed = try await webView.callAsyncJavaScript(BridgeScripts.writeSchedule,
                                                                arguments: ["doc": document.json], in: nil,
                                                                contentWorld: .page) as? Int ?? 0
            log.record(host: hostOf(webView), .appToPage, op: "schedule.write",
                       detail: "\(document.picks.count) picks, \(changed) changed, nr:schedule fired",
                       outcome: changed < 0 ? .failed : .ok, durationMs: Date().timeIntervalSince(started) * 1000)
        } catch {
            log.record(host: hostOf(webView), .appToPage, op: "schedule.write", detail: error.localizedDescription,
                       outcome: .failed)
        }
    }

    private func scheduleChangedNatively() {
        guard let change = schedule.lastChange, change.source != .web else { return }
        let targets = scheduleViews()
        guard !targets.isEmpty else { return }
        Task {
            for webView in targets { await pushSchedule(to: webView) }
            schedule.markSynced(.web, document: schedule.document)
            lastScheduleSync = .now
        }
    }

    // MARK: Meter

    func readMeter(from webView: WKWebView) async {
        do {
            let value = try await webView.callAsyncJavaScript(BridgeScripts.readMeter, arguments: [:], in: nil,
                                                              contentWorld: .page) as? String ?? ""
            meter.update(from: (try? JSONSerialization.jsonObject(with: Data(value.utf8))) as? [String: Any])
            log.record(host: hostOf(webView), .appToPage, op: "meter.read",
                       detail: meter.snapshot.map { "balance \($0.balance)p" } ?? "no meter yet")
        } catch {
            log.record(host: hostOf(webView), .appToPage, op: "meter.read", detail: error.localizedDescription,
                       outcome: .failed)
        }
    }

    private func applyPendingCredits() {
        let targets = scheduleViews()
        Task { for webView in targets { await creditPending(in: webView) } }
    }

    /// Writes App Store credit into the page's meter, once per transaction.
    func creditPending(in webView: WKWebView) async {
        for credit in meter.pendingCredits {
            do {
                let result = try await webView.callAsyncJavaScript(
                    BridgeScripts.creditMeter, arguments: ["amount": credit.pence, "ref": credit.reference], in: nil,
                    contentWorld: .page) as? String ?? "failed"
                // "credited" or "already" is the page's answer; it counts only if the page's storage, read from the
                // bridge's own content world (which page scripts cannot patch), now holds this transaction (S7).
                var confirmed = false
                if result != "failed" { confirmed = await meterHolds(credit.reference, in: webView) }
                log.record(host: hostOf(webView), .appToPage, op: "meter.credit",
                           detail: "\(credit.pence)p, \(credit.reference): \(result)\(confirmed ? ", confirmed" : ", not confirmed")",
                           outcome: confirmed ? .ok : .failed)
                if confirmed { meter.markCredited(credit) }
            } catch {
                log.record(host: hostOf(webView), .appToPage, op: "meter.credit", detail: error.localizedDescription,
                           outcome: .failed)
            }
        }
        await readMeter(from: webView)
    }

    /// Whether the page's meter (localStorage) records this App Store transaction among its credited references.
    func meterHolds(_ reference: String, in webView: WKWebView) async -> Bool {
        (try? await webView.callAsyncJavaScript(BridgeScripts.meterHasReference, arguments: ["ref": reference],
                                                in: nil, contentWorld: Self.world) as? Bool) ?? false
    }

    // MARK: Team identity

    private func identityChanged() {
        let targets = views.allObjects.filter { Self.teamHosts.contains($0.url?.host?.lowercased() ?? "") }
        Task { for webView in targets { await writeIdentity(to: webView) } }
    }

    func writeIdentity(to webView: WKWebView) async {
        let id = identity.current?.id ?? ""
        do {
            let changed = try await webView.callAsyncJavaScript(BridgeScripts.writeTeamIdentity, arguments: ["id": id],
                                                                in: nil, contentWorld: .page) as? Bool ?? false
            log.record(host: hostOf(webView), .appToPage, op: "identity.write",
                       detail: id.isEmpty ? "cleared" : "ws.me = \(id)\(changed ? ", reloading" : "")")
            if changed { webView.reload() }
        } catch {
            log.record(host: hostOf(webView), .appToPage, op: "identity.write", detail: error.localizedDescription,
                       outcome: .failed)
        }
    }

    private func hostOf(_ webView: WKWebView) -> String { webView.url?.host ?? "?" }
}
