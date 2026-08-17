import Foundation
import Testing
@testable import HSclubs

@MainActor
struct DirectoryViewModelTests {
    @Test func displaysFreshNetworkPayload() async {
        let api = FakeSchoolsAPI(outcome: .success(Fixtures.data("schools-page-full.json")))
        let repository = SchoolsRepository(api: api, cache: FakeSchoolsCache())
        let model = DirectoryViewModel(repository: repository)

        await model.loadIfNeeded()

        #expect(model.payload?.totals.clubs == 106)
        #expect(model.cachedAt == nil)
        #expect(model.errorMessage == nil)
        #expect(model.isLoading == false)
        #expect(model.isRefreshing == false)
    }

    @Test func displaysTimestampedCacheWhenOffline() async {
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cachedData = Fixtures.data("schools-page-full.json")
        let cache = FakeSchoolsCache(
            stored: CachedSchoolsPageData(data: cachedData, savedAt: cachedAt)
        )
        let api = FakeSchoolsAPI(outcome: .failure(.transport("offline")))
        let repository = SchoolsRepository(api: api, cache: cache)
        let model = DirectoryViewModel(repository: repository)

        await model.loadIfNeeded()

        #expect(model.payload?.schools.count == 3)
        #expect(model.cachedAt == cachedAt)
        #expect(model.errorMessage == "Showing saved data. Check your connection and try again.")
    }

    @Test func searchFiltersSchoolsAndClearSearchRestoresThem() async {
        let api = FakeSchoolsAPI(outcome: .success(Fixtures.data("schools-page-full.json")))
        let repository = SchoolsRepository(api: api, cache: FakeSchoolsCache())
        let model = DirectoryViewModel(repository: repository)
        await model.loadIfNeeded()

        model.query = "riverbend"
        #expect(model.schools.map(\.slug) == ["riverbend-high"])

        model.clearSearch()

        #expect(model.query.isEmpty)
        #expect(model.schools.count == 3)
    }
}
