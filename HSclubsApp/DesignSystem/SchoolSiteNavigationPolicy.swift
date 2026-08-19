import Foundation
import WebKit

/// What to do with a navigation the school web view is about to make.
///
/// Pulled out of the web view as a pure decision so the whole boundary can be tested: the loose
/// interim rule that let any non-user cross-origin navigation stay in the web view is gone, and
/// with it the risk that a scripted redirect could quietly drive the session somewhere else. The
/// only way out to another origin now is a link the person tapped (to the system browser) or the
/// mobile-auth entry (to `ASWebAuthenticationSession`).
enum SchoolSiteNavigationDecision: Equatable {
    /// Stays in the WKWebView, keeping the school's session cookies in this data store.
    case allowInWebView
    /// Handed to the system (Safari, mail, tel): a link the person chose to follow off-origin.
    case openExternally
    /// The fixed sign-in entry: start the native flow instead of loading it here.
    case startMobileAuth(returnTo: String?)
    /// Refused: non-https where a tap is not involved, an unregistered scripted cross-origin
    /// redirect, or an unsupported scheme arriving without user intent.
    case cancel
}

struct SchoolSiteNavigationPolicy {
    /// The one origin the guiding page verified for this school. Same-origin is defined against it.
    let expectedHost: String

    func decide(
        url: URL?,
        navigationType: WKNavigationType,
        isMainFrame: Bool,
        sourceURL: URL?
    ) -> SchoolSiteNavigationDecision {
        guard let url else { return .cancel }

        // Anything but https may only leave on a deliberate tap (mailto:, tel:, maps...). A
        // scripted or redirect navigation to a non-https scheme is rejected outright -- this is
        // where a custom-scheme hijack would try to get in.
        guard url.scheme?.lowercased() == "https" else {
            return isMainFrame && navigationType == .linkActivated ? .openExternally : .cancel
        }

        // Subframes and iframes are subresources, not the top-level session; allow https ones and
        // let the non-https case above have already refused the rest.
        guard isMainFrame else { return .allowInWebView }

        let sameOrigin = url.host?.caseInsensitiveCompare(expectedHost) == .orderedSame
        if sameOrigin {
            if url.path == MobileAuthConfig.startPath {
                return .startMobileAuth(returnTo: sameOriginPath(sourceURL))
            }
            return .allowInWebView
        }

        // Cross-origin, top-level: a link the person tapped goes to the system browser; anything
        // else -- a redirect, a form post, a scripted navigation -- is refused. OAuth does not
        // travel this path any more; it goes through the mobile-auth entry only.
        return navigationType == .linkActivated ? .openExternally : .cancel
    }

    /// A decision for a request to open a new window (`window.open`, target=_blank).
    ///
    /// No new window is ever spawned: a same-origin request is folded back into the current web
    /// view, an off-origin https one goes to the system browser, and anything else is refused.
    func decideNewWindow(url: URL?) -> SchoolSiteNavigationDecision {
        guard let url, url.scheme?.lowercased() == "https" else { return .cancel }
        let sameOrigin = url.host?.caseInsensitiveCompare(expectedHost) == .orderedSame
        return sameOrigin ? .allowInWebView : .openExternally
    }

    /// The source page's site-relative path, when it is on this origin, to return to after auth.
    private func sameOriginPath(_ sourceURL: URL?) -> String? {
        guard
            let sourceURL,
            sourceURL.host?.caseInsensitiveCompare(expectedHost) == .orderedSame,
            let components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false)
        else { return nil }
        let path = components.path.isEmpty ? "/" : components.path
        if let query = components.query, !query.isEmpty {
            return path + "?" + query
        }
        return path
    }
}
