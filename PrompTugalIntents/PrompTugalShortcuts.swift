import AppIntents

/// Siri and Spotlight phrases for the intents in this extension. Every phrase
/// must contain the app name.
struct PrompTugalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NextSessionIntent(),
                    phrases: ["What's next in \(.applicationName)",
                              "Next session in \(.applicationName)",
                              "What's on now in \(.applicationName)"],
                    shortTitle: "Next session",
                    systemImageName: "calendar.badge.clock")
    }
}
