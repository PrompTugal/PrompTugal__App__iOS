import Observation
import SwiftUI
import UIKit
import WebKit
import PTCore

@MainActor
public struct WebsiteView: View {
    public init() {}

    @Environment(\.horizontalSizeClass) private var width
    @State private var directory: WebsiteDirectory?
    @State private var selectedID: String?
    @State private var browsers: [String: WebsiteBrowser] = [:]
    @State private var sidebarVisible = true
    @State private var showsShortcuts = false
    @State private var showsReader = false
    @State private var availableWidth: CGFloat = 0

    /// The shortcuts column's width for the space the view has, or nil when there is no room for it
    /// (iPad Split View or Slide Over below 600 pt): then the toolbar button opens the shortcuts as a sheet.
    public nonisolated static func sidebarWidth(for available: CGFloat) -> CGFloat? {
        available >= 600 ? min(250, (available * 0.32).rounded()) : nil
    }

    /// Whether the shortcuts can be a column here (regular width with room), rather than a sheet.
    private var sidebarFits: Bool { width == .regular && Self.sidebarWidth(for: availableWidth) != nil }

    public var body: some View {
        HStack(spacing: 0) {
            if sidebarFits, sidebarVisible, let directory, let column = Self.sidebarWidth(for: availableWidth) {
                WebsiteSidebar(directory: directory, selectedID: selectedID, select: select)
                    .frame(width: column)
                Divider()
            }
            if let selectedID, let browser = browsers[selectedID] {
                website(browser).id(selectedID)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .task {
            guard directory == nil else { return }
            let loaded = WebsiteDirectory.load()
            directory = loaded
            if let first = loaded.shortcuts.first { select(first) }
        }
        .sheet(isPresented: $showsShortcuts) {
            if let directory {
                NavigationStack {
                    WebsiteSidebar(directory: directory, selectedID: selectedID, select: select)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "Done", bundle: .module)) { showsShortcuts = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showsReader) {
            (WebBridgeHub.offlineReader?() ?? AnyView(EmptyView()))
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text(String(localized: "Offline Reader", bundle: .module)).font(.headline)
                        Spacer()
                        Button(String(localized: "Done", bundle: .module)) { showsReader = false }
                    }
                    .padding()
                    .background(.bar)
                }
        }
    }

    private func select(_ shortcut: WebsiteShortcut) {
        if browsers[shortcut.id] == nil {
            browsers[shortcut.id] = WebsiteBrowser(homeURL: shortcut.url)
        }
        selectedID = shortcut.id
        showsShortcuts = false
    }

    private func website(_ browser: WebsiteBrowser) -> some View {
        WebsiteSurface(webView: browser.webView)
            .overlay {
                if let failure = browser.failure {
                    ContentUnavailableView {
                        Label(String(localized: "Website unavailable", bundle: .module), systemImage: "wifi.slash")
                    } description: {
                        Text(failure)
                    } actions: {
                        Button(String(localized: "Try again", bundle: .module)) { browser.reload() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if browser.isLoading {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .accessibilityLabel(String(localized: "Loading website", bundle: .module))
                    }
                    HStack(spacing: 4) {
                        Button {
                            if sidebarFits { sidebarVisible.toggle() }
                            else { showsShortcuts = true }
                        } label: {
                            Label(String(localized: "Websites", bundle: .module), systemImage: "sidebar.left").labelStyle(.iconOnly)
                        }
                        Button { browser.goBack() } label: {
                            Label(String(localized: "Back", bundle: .module), systemImage: "chevron.left").labelStyle(.iconOnly)
                        }
                        .disabled(!browser.canGoBack)
                        Button { browser.goHome() } label: {
                            Label(String(localized: "Home", bundle: .module), systemImage: "house").labelStyle(.iconOnly)
                        }
                        Button { browser.reload() } label: {
                            Label(String(localized: "Reload", bundle: .module), systemImage: "arrow.clockwise").labelStyle(.iconOnly)
                        }
                        Spacer(minLength: 4)
                        Button {
                            showsReader = true
                        } label: {
                            Label(String(localized: "Offline Reader", bundle: .module), systemImage: "book")
                                .labelStyle(.iconOnly)
                        }
                    }
                    .buttonStyle(WebsiteToolbarButtonStyle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
                .background(.bar)
            }
            .task { browser.start() }
    }
}

private struct WebsiteToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .foregroundStyle(Color.accentColor)
            .opacity(enabled ? (configuration.isPressed ? 0.55 : 1) : 0.35)
    }
}

private struct WebsiteSurface: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@MainActor @Observable
private final class WebsiteBrowser: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private(set) var canGoBack = false
    private(set) var isLoading = false
    private(set) var failure: String?
    @ObservationIgnored private var backObservation: NSKeyValueObservation?
    @ObservationIgnored private var loadingObservation: NSKeyValueObservation?
    private var started = false
    private let homeURL: URL
    private var requestedURL: URL

    init(homeURL: URL) {
        self.homeURL = homeURL
        requestedURL = homeURL
        let configuration = WKWebViewConfiguration()
        // The team bridge picks the site's data store and adds the `pt` handler (contracts §4).
        WebBridgeHub.bridge?.configure(configuration, for: homeURL)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        WebBridgeHub.bridge?.attach(webView)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in self?.canGoBack = value }
        }
        loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in self?.isLoading = value }
        }
    }

    func start() {
        guard !started else { return }
        started = true
        goHome()
    }

    func goHome() { webView.load(URLRequest(url: homeURL)) }
    func goBack() { webView.goBack() }

    func reload() {
        if failure != nil {
            webView.load(URLRequest(url: requestedURL, cachePolicy: .reloadIgnoringLocalCacheData))
        } else if webView.reloadFromOrigin() == nil {
            goHome()
        }
    }

    private func isWebsite(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == homeURL.host
            && (url.port ?? 443) == (homeURL.port ?? 443) && url.user == nil && url.password == nil
    }

    private func openExternally(_ url: URL) {
        guard let scheme = url.scheme, ["https", "http", "mailto", "tel"].contains(scheme) else { return }
        UIApplication.shared.open(url)
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let frame = action.targetFrame else {
            decisionHandler(.allow)
            return
        }
        guard frame.isMainFrame else {
            decisionHandler(.allow)
            return
        }
        guard let url = action.request.url else {
            decisionHandler(.cancel)
            return
        }
        if (WebBridgeHub.bridge?.handlesNavigation(to: url) ?? false) {
            decisionHandler(.cancel)
            return
        }
        if isWebsite(url) {
            if action.request.httpMethod == "GET" { requestedURL = url }
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            if action.navigationType == .linkActivated { openExternally(url) }
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.targetFrame == nil, let url = action.request.url else { return nil }
        if (WebBridgeHub.bridge?.handlesNavigation(to: url) ?? false) { return nil }
        if isWebsite(url) {
            webView.load(action.request)
        } else if action.navigationType == .linkActivated {
            openExternally(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WebBridgeHub.bridge?.pageDidFinish(webView)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        failure = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failure = String(localized: "The website stopped responding. Try reloading the page.", bundle: .module)
    }

    private func showFailure(_ error: Error) {
        let error = error as NSError
        guard error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled else { return }
        failure = String(localized: "Check your connection and try again. Cached sessions are available in Offline Reader.", bundle: .module)
    }
}
