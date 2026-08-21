import Foundation

/// Holds the single sign-in in flight and matches a returning callback to it.
///
/// One at a time on purpose: a person signs into one school at a time, and a store that kept
/// several open flows would be a set of live `state` values waiting to be replayed. Starting a
/// new flow replaces any previous one, and a matched or rejected callback clears it, so a used or
/// stale `state` never matches twice.
@MainActor
final class MobileAuthFlowStore {
    private var pending: PendingAuthFlow?
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    var current: PendingAuthFlow? { pending }

    func begin(_ flow: PendingAuthFlow) {
        pending = flow
    }

    func clear() {
        pending = nil
    }

    /// The result of a returning callback, matched against the flow that started it.
    enum Match: Equatable {
        /// The provider succeeded and everything lines up: hand this to the completion step.
        case ready(flow: PendingAuthFlow, code: String)
        /// The person cancelled at the provider. Not an error to report, just a return to the list.
        case cancelled
        /// A recoverable failure the person should see, with the flow already cleared.
        case rejected(MobileAuthRejection)
    }

    /// Matches a callback and consumes the pending flow.
    ///
    /// Once state matches, every outcome consumes the flow, so a duplicate callback cannot replay
    /// it. A mismatched state leaves the legitimate flow intact rather than letting an unrelated
    /// callback invalidate an in-progress sign-in.
    func match(_ callback: MobileAuthCallback) -> Match {
        guard let flow = pending else {
            // No flow: either the app never started one, or this is a duplicate arriving after the
            // first was consumed. Both are "unknown state" from here.
            return .rejected(.unknownState)
        }

        // State is checked before anything else and before the flow is trusted: a callback whose
        // state does not match a pending flow is treated as hostile, not as a retry.
        guard callback.state == flow.state else {
            return .rejected(.unknownState)
        }

        // From here the flow is spent no matter the outcome.
        pending = nil

        guard callback.schoolId == flow.schoolId else {
            return .rejected(.schoolMismatch)
        }
        if flow.isExpired(now: now()) {
            return .rejected(.expired)
        }

        switch callback.payload {
        case .code(let code):
            return .ready(flow: flow, code: code)
        case .error(let error):
            // access_denied is the person closing the sheet; everything else is a provider or
            // deployment failure that a retry might clear.
            return error == "access_denied" ? .cancelled : .rejected(.provider(error))
        }
    }
}

/// A recoverable mobile-auth failure, in terms the UI can turn into one sentence and a retry.
enum MobileAuthRejection: Equatable, Sendable {
    case unknownState
    case schoolMismatch
    case expired
    case provider(String)

    var message: String {
        switch self {
        case .unknownState:
            return "That sign-in could not be matched to a request from this app. Please try again."
        case .schoolMismatch:
            return "That sign-in was for a different school. Please try again."
        case .expired:
            return "That sign-in took too long. Please try again."
        case .provider:
            return "Sign-in did not complete. Please try again."
        }
    }
}
