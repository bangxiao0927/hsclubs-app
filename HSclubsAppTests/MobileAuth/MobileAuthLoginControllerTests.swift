import Foundation
import Testing
@testable import HSclubs

@MainActor
struct MobileAuthLoginControllerTests {
    private static let schoolId = "sch_alphaAAAAAAAAAAAAA"
    private static let fixedState = "fixed-state-value-1234"
    private static let fixedPkce = MobileAuthPkce.Pair(verifier: "verifier-value", challenge: "challenge-value")

    private func school(mobileAuth: Bool = true, status: DirectorySchool.IntegrationStatus = .compatible) -> DirectorySchool {
        DirectorySchool(
            schoolId: Self.schoolId,
            slug: "alpha",
            name: "Alpha Academy",
            shortName: nil,
            siteOrigin: URL(string: "https://alpha.example")!,
            host: "alpha.example",
            demo: false,
            integrationStatus: status,
            unavailableReason: nil,
            clubCount: nil,
            lastUpdatedAt: nil,
            mobileAuth: mobileAuth)
    }

    private func controller(_ webAuth: StubWebAuth) -> MobileAuthLoginController {
        MobileAuthLoginController(
            webAuth: webAuth,
            makeState: { Self.fixedState },
            makePkce: { Self.fixedPkce })
    }

    @Test func completesTheHappyPathAndSpendsTheCodeInTheWebView() async {
        let completer = StubCompleter()
        let login = controller(StubWebAuth(behavior: .succeed(code: "K7hQ")))

        await login.signIn(to: school(), returnTo: "/clubs", using: completer)

        #expect(login.state == .idle)
        #expect(completer.calls.count == 1)
        #expect(completer.calls.first?.code == "K7hQ")
        #expect(completer.calls.first?.codeVerifier == Self.fixedPkce.verifier)
        #expect(completer.calls.first?.returnTo == "/clubs")
    }

    @Test func aCancelledSheetEndsQuietly() async {
        let completer = StubCompleter()
        let login = controller(StubWebAuth(behavior: .fail(.cancelled)))

        await login.signIn(to: school(), returnTo: nil, using: completer)

        #expect(login.state == .idle)
        #expect(completer.calls.isEmpty)
    }

    @Test func aTimeoutIsARecoverableFailure() async {
        let login = controller(StubWebAuth(behavior: .fail(.timedOut)))
        await login.signIn(to: school(), returnTo: nil, using: StubCompleter())
        #expect(login.state == .failed("Sign-in timed out. Please try again."))
    }

    @Test func aNetworkFailureSurfacesItsMessage() async {
        let login = controller(StubWebAuth(behavior: .fail(.failed("no network"))))
        await login.signIn(to: school(), returnTo: nil, using: StubCompleter())
        #expect(login.state == .failed("no network"))
    }

    @Test func aProviderCancelOnTheCallbackEndsQuietly() async {
        let login = controller(StubWebAuth(behavior: .errorCallback("access_denied")))
        await login.signIn(to: school(), returnTo: nil, using: StubCompleter())
        #expect(login.state == .idle)
    }

    @Test func aMismatchedStateIsRejected() async {
        let login = controller(StubWebAuth(behavior: .succeedWithState("someone-elses", code: "K7hQ")))
        await login.signIn(to: school(), returnTo: nil, using: StubCompleter())
        if case .failed = login.state {} else { Issue.record("expected a failure, got \(login.state)") }
    }

    @Test func aSchoolWithoutMobileAuthCannotSignIn() async {
        let completer = StubCompleter()
        let login = controller(StubWebAuth(behavior: .succeed(code: "K7hQ")))
        await login.signIn(to: school(mobileAuth: false), returnTo: nil, using: completer)
        if case .failed = login.state {} else { Issue.record("expected a failure") }
        #expect(completer.calls.isEmpty)
    }

    @Test func aCompleteFailureSurfacesAMessage() async {
        let completer = StubCompleter(failure: "could not complete")
        let login = controller(StubWebAuth(behavior: .succeed(code: "K7hQ")))
        await login.signIn(to: school(), returnTo: nil, using: completer)
        #expect(login.state == .failed("could not complete"))
    }

    @Test func onlyOneSignInRunsAtATime() async {
        let webAuth = StubWebAuth(behavior: .suspend)
        let login = controller(webAuth)
        let completer = StubCompleter()

        // First sign-in suspends inside the web auth session.
        let first = Task { await login.signIn(to: school(), returnTo: nil, using: completer) }
        while webAuth.callCount == 0 { await Task.yield() }

        // A second attempt while one is in flight is ignored: the web auth is not entered again.
        await login.signIn(to: school(), returnTo: nil, using: completer)
        #expect(webAuth.callCount == 1)

        webAuth.resume(withCode: "K7hQ")
        await first.value
        #expect(login.state == .idle)
    }
}

/// A controllable stand-in for the system sign-in sheet.
final class StubWebAuth: WebAuthenticating, @unchecked Sendable {
    enum Behavior {
        case succeed(code: String)
        case succeedWithState(String, code: String)
        case errorCallback(String)
        case fail(WebAuthenticationError)
        case suspend
    }

    private let behavior: Behavior
    private(set) var callCount = 0
    private var suspended: (CheckedContinuation<Result<URL, WebAuthenticationError>, Never>, URL)?

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func authenticate(startURL: URL) async -> Result<URL, WebAuthenticationError> {
        callCount += 1
        switch behavior {
        case .succeed(let code):
            return .success(callback(from: startURL, stateOverride: nil, code: code, error: nil))
        case .succeedWithState(let state, let code):
            return .success(callback(from: startURL, stateOverride: state, code: code, error: nil))
        case .errorCallback(let error):
            return .success(callback(from: startURL, stateOverride: nil, code: nil, error: error))
        case .fail(let error):
            return .failure(error)
        case .suspend:
            return await withCheckedContinuation { continuation in
                self.suspended = (continuation, startURL)
            }
        }
    }

    func resume(withCode code: String) {
        guard let (continuation, startURL) = suspended else { return }
        suspended = nil
        continuation.resume(returning: .success(callback(from: startURL, stateOverride: nil, code: code, error: nil)))
    }

    private func callback(from startURL: URL, stateOverride: String?, code: String?, error: String?) -> URL {
        let query = URLComponents(url: startURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String { query.first { $0.name == name }?.value ?? "" }
        var components = URLComponents()
        components.scheme = "https"
        components.host = MobileAuthConfig.callbackHost
        components.path = MobileAuthConfig.callbackPath
        var items = [
            URLQueryItem(name: "schoolId", value: value("schoolId")),
            URLQueryItem(name: "state", value: stateOverride ?? value("state")),
        ]
        if let code { items.append(URLQueryItem(name: "code", value: code)) }
        if let error { items.append(URLQueryItem(name: "error", value: error)) }
        components.queryItems = items
        return components.url!
    }
}

@MainActor
final class StubCompleter: SchoolSessionCompleting {
    struct Call: Equatable {
        let schoolId: String
        let code: String
        let codeVerifier: String
        let returnTo: String?
    }

    private let failure: String?
    private(set) var calls: [Call] = []

    init(failure: String? = nil) {
        self.failure = failure
    }

    func completeSignIn(schoolId: String, code: String, codeVerifier: String, returnTo: String?) async -> String? {
        calls.append(Call(schoolId: schoolId, code: code, codeVerifier: codeVerifier, returnTo: returnTo))
        return failure
    }
}
