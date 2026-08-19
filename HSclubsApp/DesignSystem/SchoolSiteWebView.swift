import SwiftUI
import WebKit

struct SchoolSiteWebView: UIViewRepresentable {
    let url: URL
    let onLoadingChanged: (Bool) -> Void
    let onFailure: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            expectedHost: url.host,
            onLoadingChanged: onLoadingChanged,
            onFailure: onFailure
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let expectedHost: String?
        private let onLoadingChanged: (Bool) -> Void
        private let onFailure: (String) -> Void

        init(
            expectedHost: String?,
            onLoadingChanged: @escaping (Bool) -> Void,
            onFailure: @escaping (String) -> Void
        ) {
            self.expectedHost = expectedHost
            self.onLoadingChanged = onLoadingChanged
            self.onFailure = onFailure
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            if navigationAction.navigationType == .other && url.absoluteString.hasPrefix("about:") {
                return .allow
            }

            guard navigationAction.targetFrame?.isMainFrame != false else {
                return url.scheme == "https" ? .allow : .cancel
            }

            guard url.scheme == "https" else {
                return .cancel
            }

            guard let expectedHost else {
                Task { @MainActor in
                    await UIApplication.shared.open(url)
                }
                return .cancel
            }

            if url.host?.caseInsensitiveCompare(expectedHost) == .orderedSame {
                return .allow
            }

            // OAuth flows (for example Google) are full-page cross-origin redirects.
            // Keep redirects, form submissions, and scripted navigations in the same
            // WebView so the resulting session cookie stays in this data store.
            if navigationAction.navigationType != .linkActivated {
                return .allow
            }

            // A user can already be on an OAuth provider's page. Follow links within
            // that external flow instead of bouncing to Safari mid-login.
            if let currentHost = navigationAction.sourceFrame.request.url?.host,
               currentHost.caseInsensitiveCompare(expectedHost) != .orderedSame {
                return .allow
            }

            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
            return .cancel
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
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
