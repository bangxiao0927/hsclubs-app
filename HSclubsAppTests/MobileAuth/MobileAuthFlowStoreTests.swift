import Foundation
import Testing
@testable import HSclubs

@MainActor
struct MobileAuthFlowStoreTests {
    private func flow(
        state: String = "state-1",
        schoolId: String = "sch_a",
        startedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> PendingAuthFlow {
        PendingAuthFlow(state: state, schoolId: schoolId, codeVerifier: "verifier", returnTo: nil, startedAt: startedAt)
    }

    private func callback(state: String = "state-1", schoolId: String = "sch_a", code: String = "K7hQ") -> MobileAuthCallback {
        MobileAuthCallback(schoolId: schoolId, state: state, payload: .code(code))
    }

    @Test func matchesACallbackToItsFlow() {
        let store = MobileAuthFlowStore(now: { Date(timeIntervalSince1970: 1_010) })
        store.begin(flow())

        #expect(store.match(callback()) == .ready(flow: flow(), code: "K7hQ"))
        // The flow is spent: a second delivery finds nothing pending.
        #expect(store.match(callback()) == .rejected(.unknownState))
    }

    @Test func rejectsACallbackWithNoPendingFlow() {
        let store = MobileAuthFlowStore()
        #expect(store.match(callback()) == .rejected(.unknownState))
    }

    @Test func rejectsAMismatchedStateWithoutConsumingTheFlow() {
        let store = MobileAuthFlowStore(now: { Date(timeIntervalSince1970: 1_010) })
        store.begin(flow())

        #expect(store.match(callback(state: "someone-elses")) == .rejected(.unknownState))
        // The real callback still works: a hostile state did not burn the pending flow.
        #expect(store.match(callback()) == .ready(flow: flow(), code: "K7hQ"))
    }

    @Test func rejectsAMismatchedSchool() {
        let store = MobileAuthFlowStore(now: { Date(timeIntervalSince1970: 1_010) })
        store.begin(flow())
        #expect(store.match(callback(schoolId: "sch_other")) == .rejected(.schoolMismatch))
    }

    @Test func rejectsAnExpiredFlow() {
        let store = MobileAuthFlowStore(now: { Date(timeIntervalSince1970: 100_000) })
        store.begin(flow(startedAt: Date(timeIntervalSince1970: 1_000)))
        #expect(store.match(callback()) == .rejected(.expired))
    }

    @Test func treatsAccessDeniedAsCancelAndOtherErrorsAsRecoverable() {
        let store = MobileAuthFlowStore(now: { Date(timeIntervalSince1970: 1_010) })
        store.begin(flow())
        #expect(store.match(MobileAuthCallback(schoolId: "sch_a", state: "state-1", payload: .error("access_denied"))) == .cancelled)

        store.begin(flow())
        #expect(store.match(MobileAuthCallback(schoolId: "sch_a", state: "state-1", payload: .error("temporarily_unavailable"))) == .rejected(.provider("temporarily_unavailable")))
    }
}
