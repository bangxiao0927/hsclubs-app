import Foundation
import Testing
import WebKit
@testable import HSclubs

@MainActor
struct SchoolSiteNavigationPolicyTests {
    private let policy = SchoolSiteNavigationPolicy(expectedHost: "alpha.example")
    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func keepsSameOriginNavigationInTheWebView() {
        #expect(policy.decide(
            url: url("https://alpha.example/clubs"),
            navigationType: .linkActivated,
            isMainFrame: true,
            sourceURL: url("https://alpha.example/")) == .allowInWebView)
    }

    @Test func sendsUserTappedExternalLinksToTheSystemBrowser() {
        #expect(policy.decide(
            url: url("https://other.example/page"),
            navigationType: .linkActivated,
            isMainFrame: true,
            sourceURL: url("https://alpha.example/")) == .openExternally)
    }

    // The rule this issue removes: a scripted or redirect cross-origin navigation is now refused,
    // not silently allowed to stay in the web view.
    @Test func refusesScriptedCrossOriginRedirects() {
        for type in [WKNavigationType.other, .formSubmitted, .formResubmitted, .reload] {
            #expect(policy.decide(
                url: url("https://accounts.google.com/o/oauth2/auth"),
                navigationType: type,
                isMainFrame: true,
                sourceURL: url("https://alpha.example/")) == .cancel)
        }
    }

    @Test func startsMobileAuthOnlyForTheFixedEntryOnTheVerifiedOrigin() {
        #expect(policy.decide(
            url: url("https://alpha.example/api/mobile-auth/start?x=1"),
            navigationType: .linkActivated,
            isMainFrame: true,
            sourceURL: url("https://alpha.example/clubs?tab=members")) == .startMobileAuth(returnTo: "/clubs?tab=members"))

        // The same path on another origin is not the entry: it is just a cross-origin link.
        #expect(policy.decide(
            url: url("https://evil.example/api/mobile-auth/start"),
            navigationType: .linkActivated,
            isMainFrame: true,
            sourceURL: url("https://alpha.example/")) == .openExternally)
    }

    @Test func rejectsNonHttpsUnlessItIsAUserTap() {
        #expect(policy.decide(
            url: url("http://alpha.example/"),
            navigationType: .other,
            isMainFrame: true,
            sourceURL: nil) == .cancel)
        // A tapped mailto/tel is handed to the system.
        #expect(policy.decide(
            url: url("mailto:club@alpha.example"),
            navigationType: .linkActivated,
            isMainFrame: true,
            sourceURL: url("https://alpha.example/")) == .openExternally)
        // A scripted custom-scheme navigation is refused.
        #expect(policy.decide(
            url: url("weirdapp://open"),
            navigationType: .other,
            isMainFrame: true,
            sourceURL: url("https://alpha.example/")) == .cancel)
    }

    @Test func allowsHttpsSubframesAndRefusesNonHttpsOnes() {
        #expect(policy.decide(
            url: url("https://cdn.other.example/widget"),
            navigationType: .other,
            isMainFrame: false,
            sourceURL: url("https://alpha.example/")) == .allowInWebView)
        #expect(policy.decide(
            url: url("http://cdn.other.example/widget"),
            navigationType: .other,
            isMainFrame: false,
            sourceURL: url("https://alpha.example/")) == .cancel)
    }

    @Test func neverOpensANewWindowAndRoutesByOrigin() {
        #expect(policy.decideNewWindow(url: url("https://alpha.example/popup")) == .allowInWebView)
        #expect(policy.decideNewWindow(url: url("https://other.example/popup")) == .openExternally)
        #expect(policy.decideNewWindow(url: url("http://alpha.example/popup")) == .cancel)
    }
}
