import SwiftUI
import WebKit
import PTCore

/// One web page inside the shell: a web view with a progress bar, back, reload and
/// "open in Safari". Navigations are logged for the Network debug panel.
/// It shares the default website data store with the website shell, so sign-ins carry over.
public struct WebPage: View {
    public init(url: URL, title: String = "", showsToolbar: Bool = true) {
        self.url = url
        self.title = title
        self.showsToolbar = showsToolbar
    }

    public let url: URL
    public var title: String = ""
    public var showsToolbar = true
    @State private var model: WebPageModel?

    public var body: some View {
        Group {
            if let model {
                WebViewSurface(webView: model.webView)
                    .overlay(alignment: .top) {
                        if model.isLoading {
                            ProgressView(value: model.progress)
                                .progressViewStyle(.linear)
                                .tint(Palette.red)
                                .accessibilityLabel("Loading page")
                        }
                    }
                    .overlay {
                        if let failure = model.failure {
                            ContentUnavailableView {
                                Label("Page unavailable", systemImage: "wifi.slash")
                            } description: {
                                Text(failure)
                            } actions: {
                                Button("Try again") { model.reload() }.buttonStyle(.borderedProminent)
                            }
                            .background(Palette.paper)
                        }
                    }
                    .toolbar {
                        if showsToolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button { model.webView.goBack() } label: { Label("Back", systemImage: "chevron.left") }
                                    .disabled(!model.canGoBack)
                                Button { model.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                                if let current = model.currentURL {
                                    ShareLink(item: current) { Label("Share", systemImage: "square.and.arrow.up") }
                                    Link(destination: current) { Label("Open in Safari", systemImage: "safari") }
                                }
                            }
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(title.isEmpty ? (url.host ?? "Web") : title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: url) {
            if model?.homeURL != url { model = WebPageModel(url: url) }
            model?.start()
        }
    }
}

private struct WebViewSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@MainActor @Observable
public final class WebPageModel: NSObject, WKNavigationDelegate, WKUIDelegate {
    public let webView: WKWebView
    public let homeURL: URL
    public private(set) var isLoading = false
    public private(set) var progress = 0.0
    public private(set) var canGoBack = false
    public private(set) var currentURL: URL?
    public private(set) var failure: String?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var started = false
    @ObservationIgnored fileprivate var navigationStart = Date.now

    public init(url: URL) {
        homeURL = url
        currentURL = url
        let configuration = WKWebViewConfiguration()
        WebBridgeHub.bridge?.configure(configuration, for: url)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        WebBridgeHub.bridge?.attach(webView)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        webView.isInspectable = true   // Safari Web Inspector, for development builds only
        #endif
        observations = [
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                let value = view.isLoading
                Task { @MainActor [weak self] in self?.isLoading = value }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                let value = view.estimatedProgress
                Task { @MainActor [weak self] in self?.progress = value }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                let value = view.canGoBack
                Task { @MainActor [weak self] in self?.canGoBack = value }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                let value = view.url
                Task { @MainActor [weak self] in if let value { self?.currentURL = value } }
            },
        ]
    }

    public func start() {
        guard !started else { return }
        started = true
        webView.load(URLRequest(url: homeURL))
    }

    public func reload() {
        failure = nil
        if webView.url == nil { webView.load(URLRequest(url: homeURL)) } else { webView.reload() }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        failure = nil
        navigationStart = .now
    }

    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Every navigation, in every frame: the bridge's own routes and checkout pages (3.1.1) never load here.
        if let url = action.request.url, Self.refuses(url) {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    /// Links that ask for a new window (target=_blank, window.open) load in this page, with the same checks.
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, !Self.refuses(url) {
            webView.load(action.request)
        }
        return nil
    }

    /// True for a URL this page must not load: a checkout (CheckoutPolicy) or a page the bridge handles natively.
    public static func refuses(_ url: URL) -> Bool {
        CheckoutPolicy.isBlocked(url) || (WebBridgeHub.bridge?.handlesNavigation(to: url) ?? false)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WebBridgeHub.bridge?.pageDidFinish(webView)
        WebBridgeHub.noteCurrentPage(webView.title ?? webView.url?.host() ?? "Page", webView.url)
        guard let url = webView.url else { return }
        log(url, error: nil)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    private func fail(_ error: Error) {
        let error = error as NSError
        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else { return }
        failure = "Check your connection and try again."
        log(webView.url ?? homeURL, error: "Navigation failed (\(error.code))")
    }
}

extension WebPageModel {
    /// Web view page loads go in the same Network log as the app's own requests, marked "web view".
    /// WebKit does not report the bytes of a page, so they show as 0.
    fileprivate func log(_ url: URL, error: String?) {
        HTTPLog.shared.append(HTTPRequestRecord(
            id: UUID(), startedAt: navigationStart, method: "PAGE", url: HTTPClient.redact(url), host: url.host() ?? "",
            label: "web view", status: error == nil ? 200 : nil, bytes: 0,
            durationMs: Date.now.timeIntervalSince(navigationStart) * 1000, error: error))
    }
}

// MARK: - The web twin

extension View {
    /// Adds a "Web original" button. On iPad the page opens beside the native screen
    /// (an inspector column), so the two can be compared; on iPhone it opens as a sheet.
    public func webTwin(_ url: URL, title: String) -> some View { modifier(WebTwinModifier(url: url, title: title)) }
}

private struct WebTwinModifier: ViewModifier {
    let url: URL
    let title: String
    @State private var shown = false
    @Environment(\.horizontalSizeClass) private var width

    func body(content: Content) -> some View {
        let toolbarContent = content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { shown.toggle() } label: {
                        Label(shown ? "Hide web original" : "Web original", systemImage: "square.split.2x1")
                    }
                    .help("Compare with the web page this screen is built from")
                }
            }
        if width == .regular {
            // iPad: the web page in a column beside the native screen.
            toolbarContent.inspector(isPresented: $shown) {
                twin.inspectorColumnWidth(min: 320, ideal: 520, max: 900)
            }
        } else {
            // iPhone: a sheet, so the twin's own title never reaches the screen's navigation bar.
            toolbarContent.sheet(isPresented: $shown) {
                twin.presentationDetents([.large, .medium])
            }
        }
    }

    private var twin: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: Space.s) {
                    KindBadge(kind: .web(url))
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    Button("Done") { shown = false }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.s)
                .background(.bar)
                WebPage(url: url, title: title, showsToolbar: false)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}
