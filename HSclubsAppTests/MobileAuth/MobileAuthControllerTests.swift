import Foundation
import Testing
@testable import HSclubs

@MainActor
struct MobileAuthControllerTests {
    private func url(_ s: String) -> URL { URL(string: s)! }

    private func started(_ controller: MobileAuthController, state: String = "xyz", schoolId: String = "sch_a") {
        controller.begin(PendingAuthFlow(
            state: state, schoolId: schoolId, codeVerifier: "verifier", returnTo: "/clubs",
            startedAt: Date()
        ))
    }

    @Test func holdsAReadyCallbackForTheCompletionStep() {
        let controller = MobileAuthController()
        started(controller)

        let handled = controller.handle(url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&code=K7hQ"))

        #expect(handled)
        #expect(controller.rejectionMessage == nil)
        let ready = controller.takeReadyCallback()
        #expect(ready?.code == "K7hQ")
        #expect(ready?.flow.returnTo == "/clubs")
        // Consumed exactly once.
        #expect(controller.takeReadyCallback() == nil)
    }

    @Test func ignoresALinkThatIsNotTheCallback() {
        let controller = MobileAuthController()
        #expect(controller.handle(url("https://clubs.bangxiao.net/")) == false)
        #expect(controller.rejectionMessage == nil)
    }

    @Test func surfacesARecoverableErrorForAnUnknownState() {
        let controller = MobileAuthController()
        // No flow started: a callback arriving out of nowhere is rejected, not acted on.
        controller.handle(url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&code=K7hQ"))

        #expect(controller.readyCallback == nil)
        #expect(controller.rejectionMessage != nil)
    }

    @Test func quietlyClearsOnCancel() {
        let controller = MobileAuthController()
        started(controller)
        controller.handle(url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&error=access_denied"))

        #expect(controller.readyCallback == nil)
        #expect(controller.rejectionMessage == nil)
    }

    // A duplicate callback (the same Universal Link delivered twice) must not replay: the second
    // finds the flow already consumed and is rejected.
    @Test func doesNotReplayADuplicateCallback() {
        let controller = MobileAuthController()
        started(controller)
        let link = url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&code=K7hQ")

        controller.handle(link)
        _ = controller.takeReadyCallback()
        controller.handle(link)

        #expect(controller.readyCallback == nil)
        #expect(controller.rejectionMessage != nil)
    }

    // Cold start: the same handling runs whether the link arrives as a URL or as the launch
    // user activity.
    @Test func handlesAColdStartUserActivity() {
        let controller = MobileAuthController()
        started(controller)
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&code=K7hQ")

        #expect(controller.handle(activity))
        #expect(controller.takeReadyCallback()?.code == "K7hQ")
    }
}
