import Foundation
import Testing
@testable import HSclubs

struct AppDirectoryDecodingTests {
    @Test func decodesTheRequiredMembersOfACompatibleSchool() throws {
        let directory = try AppDirectoryDecoder.decode(Fixtures.data("app-directory-full.json"))

        let riverbend = try #require(directory.schools.first { $0.slug == "riverbend-high" })
        #expect(riverbend.schoolId == "sch_riverbendAAAAAAAAAA")
        #expect(riverbend.name == "Riverbend High School")
        #expect(riverbend.shortName == "RHS")
        #expect(riverbend.siteOrigin == URL(string: "https://clubs.riverbend-high.example"))
        #expect(riverbend.host == "clubs.riverbend-high.example")
        #expect(riverbend.integrationStatus == .compatible)
        #expect(riverbend.clubCount == 106)
        #expect(riverbend.mobileAuth == true)
        #expect(riverbend.enterableURL == URL(string: "https://clubs.riverbend-high.example"))
    }

    @Test func ignoresUnknownMembersAndAppliesDefaults() throws {
        let directory = try AppDirectoryDecoder.decode(Fixtures.data("app-directory-full.json"))

        // "bannerImageUrl" and the top-level "nextRefreshAt" are members this build does not
        // know; decoding must not fail on them.
        let lakeside = try #require(directory.schools.first { $0.slug == "lakeside-prep" })
        #expect(lakeside.shortName == nil)
        #expect(lakeside.clubCount == nil)
        #expect(lakeside.lastUpdatedAt == nil)
        #expect(lakeside.demo == false)
        #expect(lakeside.mobileAuth == false)
        #expect(lakeside.integrationStatus == .degraded)
        #expect(lakeside.enterableURL != nil)
    }

    @Test func skipsOnlyTheSchoolMissingARequiredMember() throws {
        let directory = try AppDirectoryDecoder.decode(Fixtures.data("app-directory-full.json"))

        // The "nameless" entry has no name and is dropped; every other school survives.
        #expect(directory.schools.contains { $0.slug == "nameless" } == false)
        #expect(directory.schools.map(\.slug) == [
            "riverbend-high", "lakeside-prep", "demo-academy", "quirky"
        ])
    }

    @Test func treatsAnUnknownStatusAsNotEnterableWithoutFailing() throws {
        let directory = try AppDirectoryDecoder.decode(Fixtures.data("app-directory-full.json"))

        let quirky = try #require(directory.schools.first { $0.slug == "quirky" })
        #expect(quirky.integrationStatus == .unknown("some-future-status"))
        #expect(quirky.isEnterable == false)
        #expect(quirky.enterableURL == nil)
    }

    @Test func keepsAnIncompatibleSchoolVisibleButClosed() throws {
        let directory = try AppDirectoryDecoder.decode(Fixtures.data("app-directory-full.json"))

        let demo = try #require(directory.schools.first { $0.slug == "demo-academy" })
        #expect(demo.integrationStatus == .incompatible)
        #expect(demo.demo == true)
        #expect(demo.enterableURL == nil)
        #expect(demo.unavailableReason == "the school manifest did not match the v1 contract")
    }

    @Test func decodesDatesWithAndWithoutFractionalSeconds() throws {
        let directory = try AppDirectoryDecoder.decode(Fixtures.data("app-directory-full.json"))

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(directory.generatedAt == fractional.date(from: "2024-05-01T12:00:00.123Z"))

        let riverbend = try #require(directory.schools.first { $0.slug == "riverbend-high" })
        #expect(riverbend.lastUpdatedAt == fractional.date(from: "2024-04-29T09:15:30.500Z"))
    }

    // A body served at the v1 path that is not a v1 directory must fail the decode, so a future
    // contract cannot be rendered as if this build understood it.
    @Test func refusesAnEnvelopeFromAnotherContractOrVersion() {
        let wrongVersion = Data("""
        {"contract":"hsclubs.app-directory","version":2,"generatedAt":"2024-05-01T12:00:00Z","schools":[]}
        """.utf8)
        #expect(throws: (any Error).self) { try AppDirectoryDecoder.decode(wrongVersion) }

        let wrongContract = Data("""
        {"contract":"hsclubs.something-else","version":1,"generatedAt":"2024-05-01T12:00:00Z","schools":[]}
        """.utf8)
        #expect(throws: (any Error).self) { try AppDirectoryDecoder.decode(wrongContract) }

        let missingEnvelope = Data("""
        {"generatedAt":"2024-05-01T12:00:00Z","schools":[]}
        """.utf8)
        #expect(throws: (any Error).self) { try AppDirectoryDecoder.decode(missingEnvelope) }
    }

    @Test func rejectsAMismatchedHostAsNotEnterable() {
        let impostor = DirectorySchool(
            schoolId: "sch_impostorFFFFFFFFFF",
            slug: "impostor",
            name: "Impostor",
            shortName: nil,
            siteOrigin: URL(string: "https://evil.example")!,
            host: "school.example",
            demo: false,
            integrationStatus: .compatible,
            unavailableReason: nil,
            clubCount: nil,
            lastUpdatedAt: nil,
            mobileAuth: false
        )
        #expect(impostor.enterableURL == nil)
    }

    @Test func rejectsANonHTTPSOriginAsNotEnterable() {
        let insecure = DirectorySchool(
            schoolId: "sch_insecureGGGGGGGGGG",
            slug: "insecure",
            name: "Insecure",
            shortName: nil,
            siteOrigin: URL(string: "http://school.example")!,
            host: "school.example",
            demo: false,
            integrationStatus: .compatible,
            unavailableReason: nil,
            clubCount: nil,
            lastUpdatedAt: nil,
            mobileAuth: false
        )
        #expect(insecure.enterableURL == nil)
    }

    // A school on a non-default port publishes host:port in the directory; the enterable check must
    // compare host and port together, not the bare host, or it would reject a legitimate school.
    @Test func acceptsAnHTTPSOriginOnANonDefaultPort() {
        let ported = DirectorySchool(
            schoolId: "sch_portedHHHHHHHHHHHH",
            slug: "ported",
            name: "Ported",
            shortName: nil,
            siteOrigin: URL(string: "https://school.example:8443")!,
            host: "school.example:8443",
            demo: false,
            integrationStatus: .compatible,
            unavailableReason: nil,
            clubCount: nil,
            lastUpdatedAt: nil,
            mobileAuth: false
        )
        #expect(ported.enterableURL == URL(string: "https://school.example:8443"))
    }
}
