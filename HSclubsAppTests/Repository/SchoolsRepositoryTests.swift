import Foundation
import Testing
@testable import HSclubs

struct SchoolsRepositoryTests {
    private func directoryData(generatedAt: String) -> Data {
        Data("""
        {
          "contract": "hsclubs.app-directory",
          "version": 1,
          "generatedAt": "\(generatedAt)",
          "schools": []
        }
        """.utf8)
    }

    @Test func emitsNetworkResultWhenNoCacheIsPresent() async throws {
        let networkData = directoryData(generatedAt: "2024-05-01T12:00:00Z")
        let api = FakeSchoolsAPI(outcome: .success(networkData))
        let cache = FakeSchoolsCache()
        let repository = SchoolsRepository(api: api, cache: cache)

        var events: [SchoolsRepositoryEvent] = []
        for await event in await repository.events() {
            events.append(event)
        }

        #expect(events.count == 1)
        guard case .networkSucceeded(let directory) = events[0] else {
            Issue.record("expected .networkSucceeded, got \(events[0])")
            return
        }
        #expect(directory.schools.isEmpty)

        let stored = await cache.currentValue()
        #expect(stored?.data == networkData)
    }

    @Test func emitsCachedContentBeforeNetworkResult() async throws {
        let cachedData = directoryData(generatedAt: "2024-04-01T12:00:00Z")
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = FakeSchoolsCache(stored: CachedDirectoryData(data: cachedData, savedAt: cachedAt))

        let networkData = directoryData(generatedAt: "2024-05-01T12:00:00Z")
        let api = FakeSchoolsAPI(outcome: .success(networkData))
        let repository = SchoolsRepository(api: api, cache: cache)

        var events: [SchoolsRepositoryEvent] = []
        for await event in await repository.events() {
            events.append(event)
        }

        #expect(events.count == 2)
        guard case .cacheLoaded(let cachedDirectory, let savedAt) = events[0] else {
            Issue.record("expected .cacheLoaded first, got \(events[0])")
            return
        }
        #expect(cachedDirectory.generatedAt == ISO8601DateFormatter().date(from: "2024-04-01T12:00:00Z"))
        #expect(savedAt == cachedAt)

        guard case .networkSucceeded(let networkDirectory) = events[1] else {
            Issue.record("expected .networkSucceeded second, got \(events[1])")
            return
        }
        #expect(networkDirectory.generatedAt == ISO8601DateFormatter().date(from: "2024-05-01T12:00:00Z"))

        let stored = await cache.currentValue()
        #expect(stored?.data == networkData)
    }

    @Test func preservesCacheWhenNetworkRefreshFails() async throws {
        let cachedData = directoryData(generatedAt: "2024-04-01T12:00:00Z")
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = FakeSchoolsCache(stored: CachedDirectoryData(data: cachedData, savedAt: cachedAt))

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
        let cachedData = directoryData(generatedAt: "2024-04-01T12:00:00Z")
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = FakeSchoolsCache(stored: CachedDirectoryData(data: cachedData, savedAt: cachedAt))
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
