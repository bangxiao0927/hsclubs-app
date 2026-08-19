import Foundation
import Testing
@testable import HSclubs

struct MobileAuthCallbackTests {
    private func url(_ string: String) -> URL { URL(string: string)! }

    @Test func parsesASuccessCallback() {
        let callback = MobileAuthCallback.parse(
            url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&code=K7hQ")
        )
        #expect(callback == MobileAuthCallback(schoolId: "sch_a", state: "xyz", payload: .code("K7hQ")))
    }

    @Test func parsesAnErrorCallback() {
        let callback = MobileAuthCallback.parse(
            url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&error=access_denied")
        )
        #expect(callback?.payload == .error("access_denied"))
    }

    @Test func ignoresLinksForOtherHostsSchemesAndPaths() {
        #expect(MobileAuthCallback.parse(url("http://clubs.bangxiao.net/mobile-auth/callback?schoolId=a&state=b&code=c")) == nil)
        #expect(MobileAuthCallback.parse(url("https://evil.example/mobile-auth/callback?schoolId=a&state=b&code=c")) == nil)
        #expect(MobileAuthCallback.parse(url("https://clubs.bangxiao.net/something-else?schoolId=a&state=b&code=c")) == nil)
    }

    @Test func rejectsMissingSchoolIdOrState() {
        #expect(MobileAuthCallback.parse(url("https://clubs.bangxiao.net/mobile-auth/callback?state=b&code=c")) == nil)
        #expect(MobileAuthCallback.parse(url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=a&code=c")) == nil)
    }

    @Test func rejectsBothOrNeitherOfCodeAndError() {
        #expect(MobileAuthCallback.parse(url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=a&state=b&code=c&error=access_denied")) == nil)
        #expect(MobileAuthCallback.parse(url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=a&state=b")) == nil)
    }

    @Test func rejectsDuplicatedParameters() {
        #expect(MobileAuthCallback.parse(url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=a&schoolId=b&state=s&code=c")) == nil)
    }

    @Test func parsesFromAWebBrowsingUserActivity() {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=sch_a&state=xyz&code=K7hQ")
        #expect(MobileAuthCallback.parse(activity)?.state == "xyz")

        let wrongType = NSUserActivity(activityType: "com.example.other")
        wrongType.webpageURL = url("https://clubs.bangxiao.net/mobile-auth/callback?schoolId=a&state=b&code=c")
        #expect(MobileAuthCallback.parse(wrongType) == nil)
    }
}
