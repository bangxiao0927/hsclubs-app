import SwiftUI
import WebKit

struct SchoolSiteWebView: UIViewRepresentable {
    let url: URL
    let onLoadingChanged: (Bool) -> Void
    let onFailure: (String) -> Void
    /// The fixed sign-in entry was tapped on the verified origin; the argument is the current
    /// site-relative path, to return to after signing in.
    var onLoginRequested: ((String?) -> Void)?
    /// Hands the created web view to whatever completes the sign-in inside it.
    var onWebViewCreated: ((WKWebView) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Appends to the default UA rather than replacing it, so the school still sees a normal
        // browser UA plus a marker that the app can drive mobile auth. The marker advertises a
        // capability; it is never a credential (see contracts/v1/README.md).
        configuration.applicationNameForUserAgent = MobileAuthConfig.userAgentMarker
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        onWebViewCreated?(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            expectedHost: url.host,
            onLoadingChanged: onLoadingChanged,
            onFailure: onFailure,
            onLoginRequested: onLoginRequested
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let policy: SchoolSiteNavigationPolicy?
        private let onLoadingChanged: (Bool) -> Void
        private let onFailure: (String) -> Void
        private let onLoginRequested: ((String?) -> Void)?

        init(
            expectedHost: String?,
            onLoadingChanged: @escaping (Bool) -> Void,
            onFailure: @escaping (String) -> Void,
            onLoginRequested: ((String?) -> Void)?
        ) {
            self.policy = expectedHost.map(SchoolSiteNavigationPolicy.init(expectedHost:))
            self.onLoadingChanged = onLoadingChanged
            self.onFailure = onFailure
            self.onLoginRequested = onLoginRequested
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            if navigationAction.navigationType == .other && url.absoluteString.hasPrefix("about:") {
                return .allow
            }

            // Without a verified origin there is nothing to anchor same-origin against; refuse.
            guard let policy else { return .cancel }

            let decision = policy.decide(
                url: url,
                navigationType: navigationAction.navigationType,
                isMainFrame: navigationAction.targetFrame?.isMainFrame ?? false,
                sourceURL: navigationAction.sourceFrame.request.url)

            switch decision {
            case .allowInWebView:
                return .allow
            case .startMobileAuth(let returnTo):
                onLoginRequested?(returnTo)
                return .cancel
            case .openExternally:
                Task { @MainActor in await UIApplication.shared.open(url) }
                return .cancel
            case .cancel:
                return .cancel
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // No new window is ever created. A same-origin request is folded back into this web
            // view; an off-origin https one goes to the system browser; anything else is dropped.
            guard let policy, let url = navigationAction.request.url else { return nil }
            switch policy.decideNewWindow(url: url) {
            case .allowInWebView:
                webView.load(navigationAction.request)
            case .openExternally:
                Task { @MainActor in await UIApplication.shared.open(url) }
            default:
                break
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation
        ) {
            onLoadingChanged(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            onLoadingChanged(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation,
            withError error: Error
        ) {
            handleFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation,
            withError error: Error
        ) {
            handleFailure(error)
        }

        private func handleFailure(_ error: Error) {
            let nsError = error as NSError
            guard nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled else {
                return
            }
            onLoadingChanged(false)
            onFailure(error.localizedDescription)
        }
    }
}
