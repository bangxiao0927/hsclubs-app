import Foundation
import Testing
@testable import HSclubs

@MainActor
struct SchoolSelectionTests {
    private func school(
        id: String = "sch_alphaAAAAAAAAAAAAA",
        slug: String = "alpha",
        host: String = "alpha.example",
        status: DirectorySchool.IntegrationStatus = .compatible
    ) -> DirectorySchool {
        DirectorySchool(
            schoolId: id,
            slug: slug,
            name: "Alpha Academy",
            shortName: nil,
            siteOrigin: URL(string: "https://\(host)")!,
            host: host,
            demo: false,
            integrationStatus: status,
            unavailableReason: nil,
            clubCount: nil,
            lastUpdatedAt: nil,
            mobileAuth: false
        )
    }

    private func directory(_ schools: [DirectorySchool]) -> AppDirectory {
        AppDirectory(generatedAt: Date(timeIntervalSince1970: 0), schools: schools)
    }

    @Test func persistsTheImmutableIdentityAcrossInstances() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)

        selection.select(school())

        #expect(selection.selectedSchoolId == "sch_alphaAAAAAAAAAAAAA")
        #expect(SchoolSelection(storage: storage).selectedSchoolId == "sch_alphaAAAAAAAAAAAAA")
    }

    @Test func clearRemovesPersistedSelection() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)
        selection.select(school())

        selection.clear()

        #expect(SchoolSelection(storage: storage).selectedSchoolId == nil)
    }

    @Test func switchRequestDoesNotEraseSelectionUntilAnotherSchoolIsChosen() {
        let selection = SchoolSelection(storage: UserDefaults(suiteName: UUID().uuidString)!)
        selection.select(school())

        selection.requestSwitch()

        #expect(selection.isSwitching)
        #expect(selection.selectedSchoolId == "sch_alphaAAAAAAAAAAAAA")
    }

    // The migration this whole change exists for: a pre-v1 install remembered a slug, and the
    // first directory read maps it to the immutable id.
    @Test func migratesALegacySlugToTheMatchingIdentity() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        storage.set("alpha", forKey: SchoolSelection.legacySlugKey)
        let selection = SchoolSelection(storage: storage)

        let resumed = selection.reconcile(with: directory([school()]))

        #expect(resumed?.schoolId == "sch_alphaAAAAAAAAAAAAA")
        #expect(selection.selectedSchoolId == "sch_alphaAAAAAAAAAAAAA")
        // The legacy key is retired, so a later launch does not try to migrate it again.
        #expect(storage.string(forKey: SchoolSelection.legacySlugKey) == nil)
    }

    // After migration the school keeps working even once its slug changes: the id is what is
    // remembered, not the handle.
    @Test func reopensAfterASlugChangeOnceMigrated() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)
        selection.select(school())

        let renamed = school(slug: "alpha-academy", host: "alpha.example")
        let resumed = selection.reconcile(with: directory([renamed]))

        #expect(resumed?.slug == "alpha-academy")
    }

    @Test func dropsALegacySlugThatMatchesNoSchool() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        storage.set("ghost", forKey: SchoolSelection.legacySlugKey)
        let selection = SchoolSelection(storage: storage)

        let resumed = selection.reconcile(with: directory([school()]))

        #expect(resumed == nil)
        #expect(selection.selectedSchoolId == nil)
        #expect(storage.string(forKey: SchoolSelection.legacySlugKey) == nil)
    }

    @Test func dropsALegacySlugThatMatchesSeveralSchools() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        storage.set("shared", forKey: SchoolSelection.legacySlugKey)
        let selection = SchoolSelection(storage: storage)

        let resumed = selection.reconcile(with: directory([
            school(id: "sch_oneAAAAAAAAAAAAAAA", slug: "shared", host: "one.example"),
            school(id: "sch_twoBBBBBBBBBBBBBBB", slug: "shared", host: "two.example")
        ]))

        #expect(resumed == nil)
        #expect(selection.selectedSchoolId == nil)
    }

    // A remembered school that has gone incompatible must not strand the user on a dead site.
    @Test func clearsASelectionThatTurnedNotOpenable() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)
        selection.select(school())

        let resumed = selection.reconcile(with: directory([school(status: .incompatible)]))

        #expect(resumed == nil)
        #expect(selection.selectedSchoolId == nil)
    }

    @Test func clearsASelectionThatVanishedFromTheDirectory() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)
        selection.select(school())

        let resumed = selection.reconcile(with: directory([
            school(id: "sch_otherCCCCCCCCCCCC", slug: "other", host: "other.example")
        ]))

        #expect(resumed == nil)
        #expect(selection.selectedSchoolId == nil)
    }

    @Test func staleCacheDoesNotEraseASelectionThatReturnsFromNetwork() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        let selection = SchoolSelection(storage: storage)
        selection.select(school())

        let cachedResult = selection.reconcile(
            with: directory([school(status: .incompatible)]),
            allowDestructiveReset: false
        )
        let freshResult = selection.reconcile(with: directory([school()]))

        #expect(cachedResult == nil)
        #expect(freshResult?.schoolId == "sch_alphaAAAAAAAAAAAAA")
        #expect(selection.selectedSchoolId == "sch_alphaAAAAAAAAAAAAA")
    }

    @Test func keepsAMigratedSelectionAcrossRelaunchWithoutTheLegacyKey() {
        let storage = UserDefaults(suiteName: UUID().uuidString)!
        storage.set("alpha", forKey: SchoolSelection.legacySlugKey)
        _ = SchoolSelection(storage: storage).reconcile(with: directory([school()]))

        // A fresh instance (a relaunch) reads the versioned selection, not the retired slug.
        let relaunched = SchoolSelection(storage: storage)
        #expect(relaunched.selectedSchoolId == "sch_alphaAAAAAAAAAAAAA")
        #expect(relaunched.pendingLegacySlug == nil)
    }
}
