import Foundation
import Testing
@testable import HSclubs

struct MobileAuthPkceTests {
    // The pinned pair from contracts/v1/vectors/mobile-auth.json.
    @Test func derivesThePinnedChallengeFromThePinnedVerifier() {
        let challenge = MobileAuthPkce.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func generatesAFreshMatchingPairEachTime() {
        let first = MobileAuthPkce.generate()
        let second = MobileAuthPkce.generate()

        #expect(first != second)
        #expect(MobileAuthPkce.challenge(for: first.verifier) == first.challenge)
        // base64url alphabet only, no padding.
        #expect(first.verifier.allSatisfy { "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".contains($0) })
    }

    @Test func generatesHighEntropyState() {
        #expect(MobileAuthPkce.generateState() != MobileAuthPkce.generateState())
        #expect(MobileAuthPkce.generateState().count >= 43)
    }
}
