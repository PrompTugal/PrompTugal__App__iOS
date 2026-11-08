import PTAgenda
import PTCore
import PTVaultUI
import PTWeb
import SwiftUI
import UIKit

/// The public app's stores and services, created once and shared. The public app has no team: the schedule,
/// the planner and the reminders run with no team source and no identity, and the web bridge has no meter.
/// `PublicShell` injects them with `.publicFeatures()`.
@MainActor
final class PublicFeatures {
    static let shared: PublicFeatures = {
        let features = PublicFeatures()
        features.registerHubs()
        return features
    }()

    let schedule: ScheduleStore
    let reminders: ReminderScheduler
    let bridgeLog: BridgeLog
    let bridge: AppBridge
    let planner: PlannerStore
    let vaultLink: ScheduleVaultLink

    private var started = false
    private var observers: [NSObjectProtocol] = []

    init(directory: URL? = nil) {
        schedule = ScheduleStore(directory: directory)
        reminders = ReminderScheduler(schedule: schedule, team: nil, identity: nil, urlScheme: AppLinks.scheme)
        bridgeLog = BridgeLog()
        bridge = AppBridge(log: bridgeLog, services: AgendaBridgeServices(
            schedule: schedule, reminders: reminders, meter: nil, identity: nil, offersAppTopUp: false))
        planner = PlannerStore(schedule: schedule, team: nil, identity: nil)
        vaultLink = ScheduleVaultLink(schedule: schedule, log: bridgeLog, vault: PublicVaultPicks())
    }

    /// Tells the packages where the app's one bridge and schedule are. Called once, when `shared` is made.
    private func registerHubs() {
        WebBridgeHub.bridge = bridge
        // WebBridgeHub.offlineReader and .noteCurrentPage: set when the offline reader and Ask are in place.
        AgendaHub.schedule = schedule
        AgendaHub.agendaDidLoad = { [weak self] agenda in self?.agendaDidLoad(agenda) }
    }

    /// Starts the reminders and the vault link.
    func start() {
        guard !started else { return }
        started = true
        reminders.start()
        vaultLink.start()
    }

    /// The app came to the foreground: top up reminders (iOS keeps at most 64) and read the vault's picks.
    func didBecomeActive() {
        guard started else { return }
        Task {
            _ = await reminders.reschedule()
            await vaultLink.pull()
        }
    }

    /// Gives the schedule and the planner the current agenda, so picks sort and remind by start time.
    func agendaDidLoad(_ events: [Event]) {
        schedule.updateEvents(events)
        planner.updateAgenda(events)
    }
}

/// The reader's vault, for the schedule's "Save my day to the vault".
@MainActor
final class PublicVaultPicks: VaultPicksAccess {
    var hasVault: Bool { VaultSession.shared.reader != nil }
    var canSave: Bool {
        guard let reader = VaultSession.shared.reader else { return false }
        return reader.canWrite && VaultSession.shared.canPush
    }
    var openVaultID: String? { VaultSession.shared.reader?.vaultId }
    func loadPicks() async throws -> Data? { try await VaultSession.shared.loadPicks() }
    func savePicks(_ local: Data) async throws -> Data { try await VaultSession.shared.savePicks(local) }
}

extension View {
    /// Puts the public app's stores in the environment and asks for reminder permission when a page asks.
    func publicFeatures(_ features: PublicFeatures = .shared) -> some View {
        modifier(PublicFeaturesModifier(features: features))
    }
}

private struct PublicFeaturesModifier: ViewModifier {
    let features: PublicFeatures
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        @Bindable var bridge = features.bridge
        return content
            .environment(features.schedule)
            .environment(features.reminders)
            .environment(features.bridgeLog)
            .environment(features.bridge)
            .environment(features.planner)
            .environment(features.vaultLink)
            // notify.plan from a page: the permission prompt only follows a tap on this native alert.
            .alert("Turn on reminders?", isPresented: $bridge.remindersRequested) {
                Button("Turn On") {
                    Task {
                        if await features.reminders.requestAuthorization() { _ = await features.reminders.reschedule() }
                    }
                }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("PrompTugal reminds you before the sessions you pick.")
            }
            .task { features.start() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { features.didBecomeActive() }
            }
            // A tapped reminder: its <scheme>://open/… link goes through the system to the shell's onOpenURL.
            .onChange(of: features.reminders.openedURL, initial: true) { _, url in
                guard let url else { return }
                features.reminders.openedURL = nil
                UIApplication.shared.open(url)
            }
    }
}
