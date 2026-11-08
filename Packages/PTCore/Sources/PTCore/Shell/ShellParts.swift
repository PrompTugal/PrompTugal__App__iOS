import SwiftUI

// Shell parts the Team app and the public app share. Each app keeps its own root and its own list of
// destinations; only the pure UI parts live here.

/// The app's own privacy and support pages, and its independence note (guideline 5.1.1, 5.2).
public enum SupportLinks {
    public static let privacy = URL(string: "https://ios.app.promptugal.news/privacy.html")!
    public static let support = URL(string: "https://ios.app.promptugal.news/support.html")!
    public static let independence = String(localized: "PrompTugal is independent. It is not affiliated with, endorsed by or sponsored by Web Summit.", bundle: .module)
}

/// Covers the app while it is not active, so the app-switcher snapshot shows no keys, messages or chats.
public struct PrivacyCover: View {
    public init() {}

    public var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: Space.m) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.ink)
                    .frame(width: 64, height: 64)
                    .overlay(Text("PT").font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(Palette.paper))
                Text("PrompTugal").font(Typo.title)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A page a link asks to open over the shell.
public struct LinkedPage: Identifiable, Equatable {
    public let url: URL
    public let title: String
    public var id: URL { url }

    public init(url: URL, title: String) {
        self.url = url
        self.title = title
    }
}

/// Reads the page out of a `<scheme>://open/<id>` link: `session=<event slug>` becomes that event's
/// page on promptugal.news; `url=<https page>` is opened only on our own two sites.
public enum ShellLink {
    public static let allowedHosts: Set<String> = ["promptugal.news", "web-summit.sgit.ai"]

    /// - Parameter isBlocked: the app's checkout rule (`CheckoutPolicy.isBlocked` from PTWeb); PTCore cannot see PTWeb.
    public static func page(in link: URL, isBlocked: (URL) -> Bool) -> LinkedPage? {
        let items = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let slug = items.first(where: { $0.name == "session" })?.value,
           !slug.isEmpty, slug.range(of: #"^[a-z0-9][a-z0-9-]*$"#, options: .regularExpression) != nil {
            return LinkedPage(url: FeedClient.site.appendingPathComponent("events/\(slug)/index.html"), title: String(localized: "Session", bundle: .module))
        }
        if let text = items.first(where: { $0.name == "url" })?.value, let url = URL(string: text),
           url.scheme == "https", let host = url.host()?.lowercased(), allowedHosts.contains(host),
           !isBlocked(url) {
            return LinkedPage(url: url, title: String(localized: "Briefing", bundle: .module))
        }
        return nil
    }
}

extension View {
    /// Marks the screen the shell opened, for UI tests and screenshots: "pt.destination.<id>".
    public func destinationID(_ id: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier("pt.destination.\(id)")
    }
}
