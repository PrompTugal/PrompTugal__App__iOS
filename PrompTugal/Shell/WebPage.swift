import SwiftUI
import WebKit

/// One web page inside the shell: a web view with a progress bar, back, reload and
/// "open in Safari". Navigations are logged for the Network debug panel.
/// It shares the default website data store with the website shell, so sign-ins carry over.
struct WebPage: View {
    let url: URL
    var title: String = ""
    var showsToolbar = true
    @State private var model: WebPageModel?

    var body: some View {
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
final class WebPageModel: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let homeURL: URL
    private(set) var isLoading = false
    private(set) var progress = 0.0
    private(set) var canGoBack = false
    private(set) var currentURL: URL?
    private(set) var failure: String?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var started = false
    @ObservationIgnored fileprivate var navigationStart = Date.now

    init(url: URL) {
        homeURL = url
        currentURL = url
        let configuration = WKWebViewConfiguration()
        TeamFeatures.shared.bridge.configure(configuration, for: url)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        TeamFeatures.shared.bridge.attach(webView)
        webView.navigationDelegate = self
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

    func start() {
        guard !started else { return }
        started = true
        webView.load(URLRequest(url: homeURL))
    }

    func reload() {
        failure = nil
        if webView.url == nil { webView.load(URLRequest(url: homeURL)) } else { webView.reload() }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        failure = nil
        navigationStart = .now
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, TeamFeatures.shared.bridge.handlesNavigation(to: url) {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        TeamFeatures.shared.bridge.pageDidFinish(webView)
        CollabHooks.noteCurrentPage(title: webView.title ?? webView.url?.host() ?? "Page", url: webView.url)
        guard let url = webView.url else { return }
        log(url, error: nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
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
    func webTwin(_ url: URL, title: String) -> some View { modifier(WebTwinModifier(url: url, title: title)) }
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
