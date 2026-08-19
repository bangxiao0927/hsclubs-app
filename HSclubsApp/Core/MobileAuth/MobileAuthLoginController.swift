import Foundation
import Observation

/// The native mobile-auth state machine: from a tap on the school's sign-in entry to a signed-in
/// web view.
///
/// The app understands none of the OAuth provider; it only generates the flow secrets, opens the
/// system sign-in, matches the callback to the flow it started, and hands the one-time code to the
/// school's own web view to spend. It never sees a token, a password or a profile.
///
/// One sign-in at a time: a second tap while one is in flight is ignored, which bounds concurrency
/// to exactly the single pending flow the store can match.
@MainActor
@Observable
final class MobileAuthLoginController {
    enum State: Equatable {
        case idle
        case signingIn
        case completing
        case failed(String)
    }

    private(set) var state: State = .idle

    private let webAuth: WebAuthenticating
    private let flowStore: MobileAuthFlowStore
    private let makeState: () -> String
    private let makePkce: () -> MobileAuthPkce.Pair
    private let now: () -> Date

    init(
        webAuth: WebAuthenticating,
        flowStore: MobileAuthFlowStore = MobileAuthFlowStore(),
        makeState: @escaping () -> String = MobileAuthPkce.generateState,
        makePkce: @escaping () -> MobileAuthPkce.Pair = MobileAuthPkce.generate,
        now: @escaping () -> Date = Date.init
    ) {
        self.webAuth = webAuth
        self.flowStore = flowStore
        self.makeState = makeState
        self.makePkce = makePkce
        self.now = now
    }

    func dismissFailure() {
        if case .failed = state { state = .idle }
    }

    /// Runs a full sign-in for a school, completing it in the given web view.
    ///
    /// - Parameter returnTo: the site-relative path to land on afterwards, or nil for the school's
    ///   default. Only a same-origin path is ever produced by the caller; the school validates it.
    func signIn(
        to school: DirectorySchool,
        returnTo: String?,
        using completer: SchoolSessionCompleting
    ) async {
        guard state == .idle || isFailed else { return }
        // A school that does not declare mobile auth must not reach a native sign-in; there is no
        // embedded-OAuth or Safari fallback.
        guard school.mobileAuth, let origin = school.enterableURL else {
            state = .failed("This school does not support signing in from the app.")
            return
        }

        let pkce = makePkce()
        let flowState = makeState()
        let flow = PendingAuthFlow(
            state: flowState,
            schoolId: school.schoolId,
            codeVerifier: pkce.verifier,
            returnTo: returnTo,
            startedAt: now())
        flowStore.begin(flow)

        guard let startURL = buildStartURL(
            origin: origin, school: school, state: flowState, challenge: pkce.challenge, returnTo: returnTo
        ) else {
            flowStore.clear()
            self.state = .failed("Could not start sign-in.")
            return
        }

        self.state = .signingIn
        switch await webAuth.authenticate(startURL: startURL) {
        case .success(let callbackURL):
            await consume(callbackURL, using: completer)
        case .failure(.cancelled):
            flowStore.clear()
            self.state = .idle
        case .failure(.timedOut):
            flowStore.clear()
            self.state = .failed("Sign-in timed out. Please try again.")
        case .failure(.failed(let message)):
            flowStore.clear()
            self.state = .failed(message)
        }
    }

    private func consume(_ callbackURL: URL, using completer: SchoolSessionCompleting) async {
        guard let callback = MobileAuthCallback.parse(callbackURL) else {
            flowStore.clear()
            state = .failed("Sign-in returned something the app did not understand.")
            return
        }
        switch flowStore.match(callback) {
        case .ready(let flow, let code):
            state = .completing
            let failure = await completer.completeSignIn(
                schoolId: flow.schoolId,
                code: code,
                codeVerifier: flow.codeVerifier,
                returnTo: flow.returnTo)
            state = failure == nil ? .idle : .failed(failure!)
        case .cancelled:
            state = .idle
        case .rejected(let rejection):
            state = .failed(rejection.message)
        }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func buildStartURL(
        origin: URL,
        school: DirectorySchool,
        state: String,
        challenge: String,
        returnTo: String?
    ) -> URL? {
        guard var components = URLComponents(url: origin, resolvingAgainstBaseURL: false) else { return nil }
        components.path = MobileAuthConfig.startPath
        var items = [
            URLQueryItem(name: "schoolId", value: school.schoolId),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "redirect_uri", value: MobileAuthConfig.callbackURL.absoluteString),
        ]
        if let returnTo {
            items.append(URLQueryItem(name: "return_to", value: returnTo))
        }
        components.queryItems = items
        return components.url
    }
}
