import Foundation
import WebKit

/// Completes a sign-in inside the school's own web view.
///
/// Holds a weak reference to the live `WKWebView` and runs the `complete` POST there, so the
/// session cookie is set in that web view's data store -- never in the app. The one-time code and
/// verifier are handed to the page as arguments and posted with `credentials: 'include'`; nothing
/// is persisted by the app.
@MainActor
final class SchoolWebSession: SchoolSessionCompleting {
    private weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func completeSignIn(schoolId: String, code: String, codeVerifier: String, returnTo: String?) async -> String? {
        guard let webView else {
            return "The school page is not ready. Please try again."
        }

        // Runs in the page so the Set-Cookie lands in this web view. The endpoint is same-origin,
        // so a relative path keeps it on the school's own origin regardless of where it navigates.
        let script = """
        const body = JSON.stringify({ schoolId, code, code_verifier: codeVerifier });
        const response = await fetch("/api/mobile-auth/complete", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            credentials: "include",
            body
        });
        if (!response.ok) { return "error"; }
        const result = await response.json();
        const target = typeof result.returnTo === "string" ? result.returnTo : "/";
        window.location.assign(target);
        return "ok";
        """

        do {
            let result = try await webView.callAsyncJavaScript(
                script,
                arguments: ["schoolId": schoolId, "code": code, "codeVerifier": codeVerifier],
                contentWorld: .page)
            return (result as? String) == "ok" ? nil : "Sign-in could not be completed. Please try again."
        } catch {
            return "Sign-in could not be completed. Please try again."
        }
    }
}
