import Foundation
import Observation

/// Receives the mobile-auth Universal Link and turns it into something the UI can act on.
///
/// This is the return-channel half of mobile auth (hsclubs-app#2): it does not start a sign-in --
/// that is `ASWebAuthenticationSession` in hsclubs-app#3 -- it only takes the callback the system
/// hands back, matches it to the flow in `MobileAuthFlowStore`, and exposes the outcome. A ready
/// callback is held for the completion step to pick up; a cancel quietly clears; a recoverable
/// failure surfaces a message.
///
/// Nothing here logs the URL, the code, the state or the school: those are exactly the values a
/// return channel exists to keep private.
@MainActor
@Observable
final class MobileAuthController {
    private let flowStore: MobileAuthFlowStore

    init(flowStore: MobileAuthFlowStore = MobileAuthFlowStore()) {
        self.flowStore = flowStore
    }

    /// A completed callback waiting for the completion step to spend its code. hsclubs-app#3
    /// observes this; until then it is simply the proof the channel worked end to end.
    private(set) var readyCallback: (flow: PendingAuthFlow, code: String)?

    /// A recoverable failure to show the person, cleared when acknowledged.
    var rejectionMessage: String?

    /// Records a started flow. Called by the flow starter (hsclubs-app#3); exposed now so the
    /// channel can be exercised end to end.
    func begin(_ flow: PendingAuthFlow) {
        readyCallback = nil
        flowStore.begin(flow)
    }

    /// Handles a Universal Link delivered as a web-browsing user activity (cold start and
    /// foreground both arrive this way).
    @discardableResult
    func handle(_ activity: NSUserActivity) -> Bool {
        guard let callback = MobileAuthCallback.parse(activity) else { return false }
        route(callback)
        return true
    }

    /// Handles a Universal Link delivered as a URL.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let callback = MobileAuthCallback.parse(url) else { return false }
        route(callback)
        return true
    }

    private func route(_ callback: MobileAuthCallback) {
        switch flowStore.match(callback) {
        case .ready(let flow, let code):
            rejectionMessage = nil
            readyCallback = (flow, code)
        case .cancelled:
            rejectionMessage = nil
            readyCallback = nil
        case .rejected(let rejection):
            readyCallback = nil
            rejectionMessage = rejection.message
        }
    }

    /// Consumes the ready callback exactly once, for the completion step.
    func takeReadyCallback() -> (flow: PendingAuthFlow, code: String)? {
        defer { readyCallback = nil }
        return readyCallback
    }
}
