import SwiftUI

@main
struct LisbonTechFringeApp: App {
    @State private var feed = FeedStore()
    @State private var saved = SavedStore()
    @State private var app = AppState()

    init() { Wordmark.registerFonts() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(feed)
                .environment(saved)
                .environment(app)
                .tint(Palette.accent)
                .task {
                    // Unit tests run inside the app: they must not reach the network.
                    let env = ProcessInfo.processInfo.environment
                    guard env["XCTestConfigurationFilePath"] == nil, env["XCTestBundlePath"] == nil else { return }
                    await feed.refresh()
                    saved.compare(with: feed.events)
                }
        }
    }
}

/// Three tabs in the floating Liquid Glass tab bar.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            Tab("All events", systemImage: "list.bullet", value: AppState.TabID.all) {
                AllEventsView()
            }
            Tab("My events", systemImage: "bookmark", value: AppState.TabID.mine) {
                MyEventsView()
            }
            Tab("Calendar", systemImage: "calendar", value: AppState.TabID.calendar) {
                CalendarView()
            }
        }
    }
}
