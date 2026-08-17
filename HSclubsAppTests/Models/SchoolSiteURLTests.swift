import Foundation
import Testing
@testable import HSclubs

struct SchoolSiteURLTests {
    @Test func acceptsMatchingHTTPSOrigin() {
        let school = makeSchool(siteURL: "https://school.example", host: "school.example")
        #expect(school.verifiedSiteURL == URL(string: "https://school.example"))
    }

    @Test func rejectsHTTPAndMismatchedHosts() {
        #expect(makeSchool(siteURL: "http://school.example", host: "school.example").verifiedSiteURL == nil)
        #expect(makeSchool(siteURL: "https://evil.example", host: "school.example").verifiedSiteURL == nil)
    }

    private func makeSchool(siteURL: String, host: String) -> School {
        School(
            slug: "school",
            siteUrl: URL(string: siteURL),
            host: host,
            demo: false,
            status: .live,
            schoolName: "School",
            address: nil,
            clubCount: nil,
            publishedAge: nil,
            changedAge: nil,
            checkedAge: nil,
            publishedAt: nil,
            lastUpdatedAt: nil,
            trend: nil,
            lastPolledAt: nil,
            lastError: nil
        )
    }
}
