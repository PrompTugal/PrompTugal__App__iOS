import SwiftUI
import WebKit

/// The app's first screen: the RiskMandate command centre, full screen, with no browser chrome.
/// The page fills the safe area; the bands under the status bar and home indicator take the
/// page's own colour, so it reads as one native screen. A small button opens Settings.
struct CommandCentreView: View {
    @AppStorage(CommandCentreSettings.addressKey) private var address = CommandCentreSettings.defaultAddress
    @State private var page = CommandCentrePage()
    @State private var showingSettings = false

    var body: some View {
        CommandCentreSurface(webView: page.webView)
            .background(Color(uiColor: page.pageColor).ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) { settingsButton }
            .overlay { if let failure = page.failure { FailureCard(message: failure, retry: { page.reload() }) } }
            .preferredColorScheme(page.isDark ? .dark : .light)
            .sheet(isPresented: $showingSettings) {
                SettingsView(address: $address, reload: { page.reload() })
            }
            .onAppear { page.open(CommandCentreSettings.url(from: address)) }
            .onChange(of: address) { _, newValue in
                page.open(CommandCentreSettings.url(from: newValue))
            }
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.footnote.weight(.semibold))
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
        }
        .opacity(0.55)
        .padding(10)
        .accessibilityLabel("Settings")
    }
}

private struct FailureCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.title)
            Text(message).multilineTextAlignment(.center)
            Button("Try again", action: retry).buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(24)
    }
}

private struct CommandCentreSurface: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Owns the one WKWebView. Persistent default data store, so the page's localStorage
/// (the X-Ray's OpenRouter key, pasted on the device) survives restarts.
@MainActor @Observable
final class CommandCentrePage: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private(set) var failure: String?
    private(set) var pageColor: UIColor = .black
    private(set) var isDark = true
    @ObservationIgnored private var homeURL: URL?
    @ObservationIgnored private let refresh = UIRefreshControl()

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        #if DEBUG
        webView.isInspectable = true   // Safari Web Inspector, development builds only
        #endif
        refresh.addTarget(self, action: #selector(pulledToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
    }

    /// Loads `url` unless it is already the page's home.
    func open(_ url: URL) {
        guard url != homeURL else { return }
        homeURL = url
        failure = nil
        webView.load(URLRequest(url: url))
    }

    func reload() {
        failure = nil
        if webView.url == nil || webView.reload() == nil, let homeURL {
            webView.load(URLRequest(url: homeURL))
        }
    }

    @objc private func pulledToRefresh() { reload() }

    private func isHome(_ url: URL) -> Bool {
        guard let homeURL else { return false }
        return url.scheme == "https" && url.host == homeURL.host && url.port == homeURL.port
    }

    private func openExternally(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), ["https", "http", "mailto", "tel"].contains(scheme) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, let frame = action.targetFrame, frame.isMainFrame else {
            // Frames and target=_blank are handled here and in createWebViewWith.
            decisionHandler(.allow)
            return
        }
        if action.shouldPerformDownload {
            decisionHandler(.cancel)
        } else if isHome(url) || ["about", "blob", "data"].contains(url.scheme ?? "") {
            decisionHandler(.allow)
        } else {
            // Another site: Safari, never inside the command centre.
            decisionHandler(.cancel)
            openExternally(url)
        }
    }

    /// target=_blank and window.open: same site loads here, anything else opens in Safari.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url else { return nil }
        if isHome(url) {
            webView.load(action.request)
        } else {
            openExternally(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        failure = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh.endRefreshing()
        let color: UIColor = webView.themeColor ?? webView.underPageBackgroundColor ?? .black
        pageColor = color
        isDark = color.isDark
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }

    private func showFailure(_ error: Error) {
        refresh.endRefreshing()
        let error = error as NSError
        guard error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled else { return }
        failure = "The command centre could not load. Check the connection and try again."
    }

    // MARK: JavaScript alert, confirm and prompt

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in done.resume() })
            if !present(alert) { done.resume() }
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        await withCheckedContinuation { (done: CheckedContinuation<Bool, Never>) in
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in done.resume(returning: false) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in done.resume(returning: true) })
            if !present(alert) { done.resume(returning: false) }
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
        await withCheckedContinuation { (done: CheckedContinuation<String?, Never>) in
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in done.resume(returning: nil) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
                done.resume(returning: alert?.textFields?.first?.text ?? "")
            })
            if !present(alert) { done.resume(returning: nil) }
        }
    }

    /// Presents on the top view controller of the web view's window; false if there is none.
    private func present(_ controller: UIViewController) -> Bool {
        guard var top = webView.window?.rootViewController else { return false }
        while let next = top.presentedViewController { top = next }
        top.present(controller, animated: true)
        return true
    }
}

private extension UIColor {
    var isDark: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return true }
        return 0.299 * red + 0.587 * green + 0.114 * blue < 0.5
    }
}
