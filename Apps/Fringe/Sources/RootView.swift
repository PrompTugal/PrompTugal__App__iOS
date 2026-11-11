import SwiftUI
import PTAgenda
import PTCore
import PTFringe

enum FringeTab: Hashable { case now, events, plan, communities, more }

/// Four tabs. Picks are PTAgenda's ScheduleStore; local reminders are asked for only after the first pick.
struct RootView: View {
    @Environment(FringeStore.self) private var store
    @Environment(ScheduleStore.self) private var schedule
    @Environment(ReminderScheduler.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: FringeTab = .now
    @State private var askReminders = false
    @AppStorage("fringe.askedReminders") private var askedReminders = false
    @AppStorage("fringe.seenIndependence") private var seenIndependence = false

    var body: some View {
        TabView(selection: $tab) {
            NowView().tabItem { Label("Now", systemImage: "clock") }.tag(FringeTab.now)
            EventsView().tabItem { Label("Events", systemImage: "calendar") }.tag(FringeTab.events)
            PlanView(chooseEvents: { tab = .events }).tabItem { Label("My plan", systemImage: "star") }.tag(FringeTab.plan)
            CommunitiesView().tabItem { Label("Communities", systemImage: "person.3") }.tag(FringeTab.communities)
            MoreView().tabItem { Label("More", systemImage: "ellipsis.circle") }.tag(FringeTab.more)
        }
        .tint(Palette.red)
        .task {
            reminders.start()
            await store.refresh(force: true)
        }
        // The events the picks can name: refreshed whenever the list changes.
        .onChange(of: store.events, initial: true) { _, events in
            schedule.updateEvents(events.map(\.planEvent))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
        .onChange(of: schedule.picks.count) { old, new in
            if old == 0, new > 0, !askedReminders { askReminders = true }
        }
        .alert("Remind you before the events you pick?", isPresented: $askReminders) {
            Button("Turn on reminders") {
                askedReminders = true
                Task { if await reminders.requestAuthorization() { _ = await reminders.reschedule() } }
            }
            Button("Not now", role: .cancel) { askedReminders = true }
        } message: {
            Text("Reminders are local notifications on this phone. Nothing is sent anywhere.")
        }
        .sheet(isPresented: Binding(get: { !seenIndependence }, set: { if !$0 { seenIndependence = true } })) {
            IndependenceSheet { seenIndependence = true }
        }
    }
}

/// The independence line, shown once at first launch and always on About.
struct IndependenceSheet: View {
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Kicker(String(localized: "Welcome"))
            Text("Lisbon Fringe").font(Typo.display)
            Text(FringeText.independence).font(Typo.body)
            Text("It lists side events, meetups and communities from public pages, with where each one was read and when. It collects no data about you and has no account.")
                .font(Typo.meta).foregroundStyle(Palette.muted)
            Spacer()
            Button(action: done) { Text("Continue").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
        }
        .padding(Space.l)
        .background(Palette.paper.ignoresSafeArea())
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

enum FringeText {
    static let independence = String(localized: "Lisbon Fringe is independent. It is not affiliated with, endorsed by or sponsored by Web Summit.")
    static let officialSite = URL(string: "https://websummit.com/")!
    static let join = URL(string: "https://lisbontechfringe.com/join/")!
    static let submit = URL(string: "https://lisbontechfringe.com/submit/")!
    static let site = URL(string: "https://lisbontechfringe.com/")!
    static let stormSite = URL(string: "https://storm-charles.promptugal.news/")!
    static let ipma = URL(string: "https://www.ipma.pt/")!
    static let anepc = URL(string: "https://prociv.gov.pt/")!
}
