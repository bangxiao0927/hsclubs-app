import Foundation

/// Spends the one-time code for a session, inside the school's own web view.
///
/// The `complete` POST has to run in the WKWebView so the session cookie lands in that web view's
/// data store -- the whole reason a code exists rather than the app holding a token. A protocol so
/// the login state machine can be tested without a live web view.
protocol SchoolSessionCompleting: Sendable {
    /// Posts the code and verifier to the school's complete endpoint from the web view, then
    /// navigates to `returnTo`. Returns the failure message, or nil on success.
    @MainActor
    func completeSignIn(schoolId: String, code: String, codeVerifier: String, returnTo: String?) async -> String?
}
