import StoreKit
import SwiftUI

/// Asks once for an App Store rating, after the third article the person has read and closed (the competitor
/// research, 27 Nov: the apps that rank ask after a few reads, never on first launch). Apple's own sheet, so iOS
/// decides whether it actually shows and limits it to three times a year; we ask at most once per app version and
/// never before the app has been installed for two days. Article screens post `articleRead` when they close.
struct ReviewPrompt: ViewModifier {
    static let articleRead = Notification.Name("news.promptugal.reader.articleRead")
    static let readsBeforeAsking = 3

    @Environment(\.requestReview) private var requestReview
    @AppStorage("review.reads") private var reads = 0
    @AppStorage("review.askedVersion") private var askedVersion = ""
    @AppStorage("review.firstSeen") private var firstSeen = 0.0

    func body(content: Content) -> some View {
        content
            .onAppear { if firstSeen == 0 { firstSeen = Date.now.timeIntervalSince1970 } }
            .onReceive(NotificationCenter.default.publisher(for: Self.articleRead)) { _ in
                reads += 1
                guard Self.shouldAsk(reads: reads, askedVersion: askedVersion, version: Self.version,
                                     firstSeen: Date(timeIntervalSince1970: firstSeen), now: .now) else { return }
                askedVersion = Self.version
                // After the article has gone, so the sheet never covers what the person was reading.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    requestReview()
                }
            }
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func shouldAsk(reads: Int, askedVersion: String, version: String, firstSeen: Date, now: Date) -> Bool {
        reads >= readsBeforeAsking && askedVersion != version && now.timeIntervalSince(firstSeen) >= 2 * 86_400
    }
}

extension View {
    func reviewPrompt() -> some View { modifier(ReviewPrompt()) }
}
