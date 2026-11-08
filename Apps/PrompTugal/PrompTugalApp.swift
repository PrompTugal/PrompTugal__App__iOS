import SwiftUI

/// Entry point of the public PrompTugal app (news.promptugal.reader).
/// Background task ids for this app: news.promptugal.reader.refresh and
/// news.promptugal.reader.vault-refresh (both listed in Info.plist). Register them
/// here, before launch finishes, once the packages that own the tasks are on dev.
@main @MainActor
struct PrompTugalApp: App {
    var body: some Scene {
        WindowGroup {
            PublicShell()
        }
    }
}
