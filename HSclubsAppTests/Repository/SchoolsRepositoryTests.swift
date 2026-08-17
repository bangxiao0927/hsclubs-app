import Foundation
import Testing
@testable import HSclubs

struct SchoolsRepositoryTests {
    private func payloadData(title: String) -> Data {
        Data("""
        {
          "title": "\(title)",
          "generatedAt": "2024-05-01T12:00:00Z",
          "totals": { "schools": 0, "clubs": 0, "checkedAge": null },
          "schools": []
        }
        """.utf8)
    }

    @Test func emitsNetworkResultWhenNoCacheIsPresent() async throws {
        let networkData = payloadData(title: "From Network")
        let api = FakeSchoolsAPI(outcome: .success(networkData))
        let cache = FakeSchoolsCache()
        let repository = SchoolsRepository(api: api, cache: cache)

        var events: [SchoolsRepositoryEvent] = []
        for await event in await repository.events() {
            events.append(event)
        }

        #expect(events.count == 1)
        guard case .networkSucceeded(let payload) = events[0] else {
            Issue.record("expected .networkSucceeded, got \(events[0])")
            return
        }
        #expect(payload.title == "From Network")

        let stored = await cache.currentValue()
        #expect(stored?.data == networkData)
    }

    @Test func emitsCachedContentBeforeNetworkResult() async throws {
        let cachedData = payloadData(title: "From Cache")
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = FakeSchoolsCache(stored: CachedSchoolsPageData(data: cachedData, savedAt: cachedAt))

        let networkData = payloadData(title: "From Network")
        let api = FakeSchoolsAPI(outcome: .success(networkData))
        let repository = SchoolsRepository(api: api, cache: cache)

        var events: [SchoolsRepositoryEvent] = []
        for await event in await repository.events() {
            events.append(event)
        }

        #expect(events.count == 2)
        guard case .cacheLoaded(let cachedPayload, let savedAt) = events[0] else {
            Issue.record("expected .cacheLoaded first, got \(events[0])")
            return
        }
        #expect(cachedPayload.title == "From Cache")
        #expect(savedAt == cachedAt)

        guard case .networkSucceeded(let networkPayload) = events[1] else {
            Issue.record("expected .networkSucceeded second, got \(events[1])")
            return
        }
        #expect(networkPayload.title == "From Network")

        let stored = await cache.currentValue()
        #expect(stored?.data == networkData)
    }

    @Test func preservesCacheWhenNetworkRefreshFails() async throws {
        let cachedData = payloadData(title: "From Cache")
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = FakeSchoolsCache(stored: CachedSchoolsPageData(data: cachedData, savedAt: cachedAt))

        let api = FakeSchoolsAPI(outcome: .failure(.httpStatus(503)))
        let repository = SchoolsRepository(api: api, cache: cache)

        var events: [SchoolsRepositoryEvent] = []
        for await event in await repository.events() {
            events.append(event)
        }

        #expect(events.count == 2)
        guard case .cacheLoaded = events[0] else {
            Issue.record("expected .cacheLoaded first, got \(events[0])")
            return
        }
        guard case .networkFailed(let error) = events[1] else {
            Issue.record("expected .networkFailed second, got \(events[1])")
            return
        }
        #expect(error == .httpStatus(503))

        let stored = await cache.currentValue()
        #expect(stored?.data == cachedData)
        #expect(stored?.savedAt == cachedAt)
    }

    @Test func reportsInvalidNetworkJSONWithoutReplacingCache() async throws {
        let cachedData = payloadData(title: "From Cache")
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = FakeSchoolsCache(stored: CachedSchoolsPageData(data: cachedData, savedAt: cachedAt))
        let api = FakeSchoolsAPI(outcome: .success(Data("<html>maintenance</html>".utf8)))
        let repository = SchoolsRepository(api: api, cache: cache)

        var events: [SchoolsRepositoryEvent] = []
        for await event in await repository.events() {
            events.append(event)
        }

        #expect(events.count == 2)
        guard case .networkFailed(let error) = events[1] else {
            Issue.record("expected .networkFailed second, got \(events[1])")
            return
        }
        #expect(error == .invalidData)
        #expect(await cache.currentValue()?.data == cachedData)
    }
}
