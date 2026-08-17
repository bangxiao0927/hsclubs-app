import Foundation
import Testing
@testable import HSclubs

struct DirectoryQueryTests {
    @Test func searchMatchesOnlyVisibleNameAndHostIgnoringCaseAndOuterWhitespace() {
        let schools = [
            school("alpha", name: "Alpha Academy", host: "clubs.alpha.example"),
            school("beta", name: "Beta High", host: "beta.example")
        ]

        #expect(DirectoryQuery.search(schools, query: "  ACADEMY ").map(\.slug) == ["alpha"])
        #expect(DirectoryQuery.search(schools, query: "CLUBS.ALPHA").map(\.slug) == ["alpha"])
        #expect(DirectoryQuery.search(schools, query: "beta").map(\.slug) == ["beta"])
        #expect(DirectoryQuery.search(schools, query: "   ").count == 2)
    }

    @Test func sortsByNameAndKeepsEqualNamesStable() {
        let schools = [
            school("same-1", name: "Same"),
            school("z", name: "Zulu"),
            school("a", name: "Alpha"),
            school("same-2", name: "Same")
        ]

        #expect(DirectoryQuery.sortedByName(schools).map(\.slug) == [
            "a", "same-1", "same-2", "z"
        ])
    }

    private func school(_ slug: String, name: String, host: String? = nil) -> School {
        School(
            slug: slug,
            siteUrl: nil,
            host: host,
            demo: false,
            status: .live,
            schoolName: name,
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
