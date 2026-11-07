import Observation
import SwiftUI
import UIKit
import WebKit

@MainActor
struct WebsiteView: View {
    @Environment(\.horizontalSizeClass) private var width
    @State private var directory: WebsiteDirectory?
    @State private var selectedID: String?
    @State private var browsers: [String: WebsiteBrowser] = [:]
    @State private var sidebarVisible = true
    @State private var showsShortcuts = false
    @State private var showsReader = false

    var body: some View {
        HStack(spacing: 0) {
            if width == .regular, sidebarVisible, let directory {
                WebsiteSidebar(directory: directory, selectedID: selectedID, select: select)
                    .frame(width: 250)
                Divider()
            }
            if let selectedID, let browser = browsers[selectedID] {
                website(browser).id(selectedID)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
                                Button("Done") { showsShortcuts = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showsReader) {
            ReaderView()
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text("Offline Reader").font(.headline)
                        Spacer()
                        Button("Done") { showsReader = false }
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
                        Label("Website unavailable", systemImage: "wifi.slash")
                    } description: {
                        Text(failure)
                    } actions: {
                        Button("Try Again") { browser.reload() }
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
                            .accessibilityLabel("Loading website")
                    }
                    HStack(spacing: 4) {
                        Button {
                            if width == .regular { sidebarVisible.toggle() }
                            else { showsShortcuts = true }
                        } label: {
                            Label("Websites", systemImage: "sidebar.left").labelStyle(.iconOnly)
                        }
                        Button { browser.goBack() } label: {
                            Label("Back", systemImage: "chevron.left").labelStyle(.iconOnly)
                        }
                        .disabled(!browser.canGoBack)
                        Button { browser.goHome() } label: {
                            Label("Home", systemImage: "house").labelStyle(.iconOnly)
                        }
                        Button { browser.reload() } label: {
                            Label("Reload", systemImage: "arrow.clockwise").labelStyle(.iconOnly)
                        }
                        Spacer(minLength: 4)
                        Button {
                            showsReader = true
                        } label: {
                            Label("Offline Reader", systemImage: "book")
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
        TeamFeatures.shared.bridge.configure(configuration, for: homeURL)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        TeamFeatures.shared.bridge.attach(webView)
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
        if TeamFeatures.shared.bridge.handlesNavigation(to: url) {
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
        if TeamFeatures.shared.bridge.handlesNavigation(to: url) { return nil }
        if isWebsite(url) {
            webView.load(action.request)
        } else if action.navigationType == .linkActivated {
            openExternally(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        TeamFeatures.shared.bridge.pageDidFinish(webView)
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
        failure = "The website stopped responding. Try reloading the page."
    }

    private func showFailure(_ error: Error) {
        let error = error as NSError
        guard error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled else { return }
        failure = "Check your connection and try again. Cached sessions are available in Offline Reader."
    }
}
