import Foundation
import Testing
@testable import HSclubs

@MainActor
struct SchoolSelectionTests {
    @Test func persistsSelectedSchoolSlugAcrossInstances() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)

        selection.select(Self.school)

        #expect(selection.selectedSlug == "alpha")
        #expect(SchoolSelection(storage: storage).selectedSlug == "alpha")
    }

    @Test func clearRemovesPersistedSelection() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)
        selection.select(Self.school)

        selection.clear()

        #expect(SchoolSelection(storage: storage).selectedSlug == nil)
    }

    @Test func switchRequestDoesNotEraseSelectionUntilAnotherSchoolIsChosen() {
        let selection = SchoolSelection(storage: UserDefaults(suiteName: UUID().uuidString)!)
        selection.select(Self.school)

        selection.requestSwitch()

        #expect(selection.isSwitching)
        #expect(selection.selectedSlug == "alpha")
    }

    private static let school = School(
        slug: "alpha",
        siteUrl: URL(string: "https://alpha.example"),
        host: "alpha.example",
        demo: false,
        status: .live,
        schoolName: "Alpha Academy",
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
