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
    @ObservationIgnored private var navigationStart = Date.now

    init(url: URL) {
        homeURL = url
        currentURL = url
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true
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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        RequestLog.shared.record(.init(at: navigationStart, method: "WEB", url: url, status: 200, bytes: 0,
                                       durationMs: Date.now.timeIntervalSince(navigationStart) * 1000,
                                       outcome: .ok, source: "web view"))
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
        RequestLog.shared.record(.init(at: navigationStart, method: "WEB", url: webView.url ?? homeURL, status: nil,
                                       bytes: 0, durationMs: Date.now.timeIntervalSince(navigationStart) * 1000,
                                       outcome: .failed(error.localizedDescription), source: "web view"))
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

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { shown.toggle() } label: {
                        Label(shown ? "Hide web original" : "Web original", systemImage: "square.split.2x1")
                    }
                    .help("Compare with the web page this screen is built from")
                }
            }
            .inspector(isPresented: $shown) {
                NavigationStack {
                    WebPage(url: url, title: title, showsToolbar: false)
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                HStack(spacing: Space.s) {
                                    KindBadge(kind: .web(url))
                                    Text(title).font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                }
                .inspectorColumnWidth(min: 320, ideal: 520, max: 900)
            }
    }
}
