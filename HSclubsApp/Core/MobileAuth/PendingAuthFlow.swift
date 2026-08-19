import Foundation

/// A sign-in the app has started and is waiting to see returned.
///
/// Created when the app opens the system sign-in (hsclubs-app#3) and matched against the callback
/// when it returns. `state` is the app's own nonce and the only thing that ties a callback to the
/// flow that asked for it; `codeVerifier` is the PKCE secret that never leaves the device until
/// the complete step. The verifier is populated by the flow starter -- this type only has to
/// carry it so the callback channel can hand a fully-formed flow to the completion step.
struct PendingAuthFlow: Equatable, Sendable {
    let state: String
    let schoolId: String
    let codeVerifier: String
    /// A site-relative path to return to after the session exists, or nil.
    let returnTo: String?
    let startedAt: Date

    /// A flow older than this is treated as abandoned. Generous next to the one-time code's
    /// 60-120s life: this only guards against a callback arriving for a sign-in the person walked
    /// away from, not against code replay, which the school enforces.
    static let lifetime: TimeInterval = 10 * 60

    func isExpired(now: Date) -> Bool {
        now.timeIntervalSince(startedAt) > Self.lifetime
    }
}
