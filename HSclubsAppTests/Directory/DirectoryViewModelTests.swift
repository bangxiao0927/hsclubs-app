import Foundation
import Testing
@testable import HSclubs

@MainActor
struct DirectoryViewModelTests {
    @Test func displaysFreshNetworkPayload() async {
        let api = FakeSchoolsAPI(outcome: .success(Fixtures.data("app-directory-full.json")))
        let repository = SchoolsRepository(api: api, cache: FakeSchoolsCache())
        let model = DirectoryViewModel(repository: repository)

        await model.loadIfNeeded()

        // The nameless entry is dropped; the other four survive.
        #expect(model.directory?.schools.count == 4)
        #expect(model.cachedAt == nil)
        #expect(model.directoryIsAuthoritative)
        #expect(model.errorMessage == nil)
        #expect(model.isLoading == false)
        #expect(model.isRefreshing == false)
    }

    @Test func displaysTimestampedCacheWhenOffline() async {
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cachedData = Fixtures.data("app-directory-full.json")
        let cache = FakeSchoolsCache(
            stored: CachedDirectoryData(data: cachedData, savedAt: cachedAt)
        )
        let api = FakeSchoolsAPI(outcome: .failure(.transport("offline")))
        let repository = SchoolsRepository(api: api, cache: cache)
        let model = DirectoryViewModel(repository: repository)

        await model.loadIfNeeded()

        #expect(model.directory?.schools.count == 4)
        #expect(model.cachedAt == cachedAt)
        #expect(!model.directoryIsAuthoritative)
        #expect(model.errorMessage == "Showing saved data. Check your connection and try again.")
    }

    @Test func searchFiltersSchoolsAndClearSearchRestoresThem() async {
        let api = FakeSchoolsAPI(outcome: .success(Fixtures.data("app-directory-full.json")))
        let repository = SchoolsRepository(api: api, cache: FakeSchoolsCache())
        let model = DirectoryViewModel(repository: repository)
        await model.loadIfNeeded()

        model.query = "riverbend"
        #expect(model.schools.map(\.slug) == ["riverbend-high"])

        model.clearSearch()

        #expect(model.query.isEmpty)
        #expect(model.schools.count == 4)
    }
}
