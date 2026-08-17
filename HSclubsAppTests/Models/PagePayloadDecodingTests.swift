import Foundation
import Testing
@testable import HSclubs

struct PagePayloadDecodingTests {
    @Test func decodesFullPayloadFields() throws {
        let data = Fixtures.data("schools-page-full.json")

        let payload = try SchoolsPageDecoder.decode(data)

        #expect(payload.title == "HS Clubs")
        #expect(payload.totals.schools == 3)
        #expect(payload.totals.clubs == 106)
        #expect(payload.totals.checkedAge == "12 minutes ago")
        #expect(payload.schools.count == 3)

        let riverbend = try #require(payload.schools.first { $0.slug == "riverbend-high" })
        #expect(riverbend.siteUrl == URL(string: "https://clubs.riverbend-high.example"))
        #expect(riverbend.host == "clubs.riverbend-high.example")
        #expect(riverbend.demo == false)
        #expect(riverbend.location == SchoolLocation(lat: 37.359106, lon: -122.067156))
        #expect(riverbend.location?.isValid == true)
        #expect(riverbend.status == .live)
        #expect(riverbend.schoolName == "Riverbend High School")
        #expect(riverbend.address == "100 Example Ave, Riverbend, CA")
        #expect(riverbend.clubCount == 106)
        #expect(riverbend.categories.map(\.name) == [
            "Service & Leadership",
            "STEM & Innovation",
            "Culture & Identity",
            "Competition & Strategy",
            "Wellness & Athletics",
            "Creative Arts & Media"
        ])
        #expect(riverbend.categories.reduce(0) { $0 + $1.count } == riverbend.clubCount)
        #expect(riverbend.trend == 8)
        #expect(riverbend.lastError == nil)
        #expect(riverbend.history.count == 2)
        #expect(riverbend.history.last?.clubCount == 106)
    }

    @Test func decodesMissingOptionalFieldsWithDefaults() throws {
        let data = Fixtures.data("schools-page-full.json")

        let payload = try SchoolsPageDecoder.decode(data)

        let lakeside = try #require(payload.schools.first { $0.slug == "lakeside-prep" })
        #expect(lakeside.schoolName == "lakeside-prep")
        #expect(lakeside.address == nil)
        #expect(lakeside.clubCount == nil)
        #expect(lakeside.categories == [])
        #expect(lakeside.history == [])
        #expect(lakeside.trend == nil)
        #expect(lakeside.publishedAt == nil)
        #expect(lakeside.lastUpdatedAt == nil)
        #expect(lakeside.lastError == "timed out contacting host")
    }

    @Test func mapsUnknownStatusToUnknownCase() throws {
        let data = Fixtures.data("schools-page-full.json")

        let payload = try SchoolsPageDecoder.decode(data)

        let lakeside = try #require(payload.schools.first { $0.slug == "lakeside-prep" })
        #expect(lakeside.status == .unknown("quirky-new-status"))

        let demoAcademy = try #require(payload.schools.first { $0.slug == "demo-academy" })
        #expect(demoAcademy.status == .noData)
        #expect(demoAcademy.demo == true)
    }

    @Test func decodesDatesWithAndWithoutFractionalSeconds() throws {
        let data = Fixtures.data("schools-page-full.json")

        let payload = try SchoolsPageDecoder.decode(data)

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(payload.generatedAt == fractionalFormatter.date(from: "2024-05-01T12:00:00.123Z"))

        let riverbend = try #require(payload.schools.first { $0.slug == "riverbend-high" })
        #expect(riverbend.publishedAt == ISO8601DateFormatter().date(from: "2024-04-29T09:15:30Z"))
        #expect(riverbend.lastUpdatedAt == fractionalFormatter.date(from: "2024-04-29T09:15:30.500Z"))
    }

    @Test func throwsDecodingErrorForInvalidDateString() {
        let json = """
        {
          "title": "HS Clubs",
          "generatedAt": "not-a-date",
          "totals": { "schools": 0, "clubs": 0, "checkedAge": null },
          "schools": []
        }
        """
        let data = Data(json.utf8)

        #expect(throws: (any Error).self) {
            try SchoolsPageDecoder.decode(data)
        }
    }
}
