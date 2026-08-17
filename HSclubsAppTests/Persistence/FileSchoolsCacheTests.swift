import Foundation
import Testing
@testable import HSclubs

struct FileSchoolsCacheTests {
    private func makeCache() -> (FileSchoolsCache, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSchoolsCacheTests-\(UUID().uuidString)")
        return (FileSchoolsCache(directory: directory), directory)
    }

    @Test func loadReturnsNilWhenNothingHasBeenSaved() async {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loaded = await cache.load()

        #expect(loaded == nil)
    }

    @Test func savedDataCanBeLoadedBackWithTimestamp() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = Data(#"{"title":"HS Clubs"}"#.utf8)
        let savedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await cache.save(payload, savedAt: savedAt)
        let loaded = try #require(await cache.load())

        #expect(loaded.data == payload)
        #expect(loaded.savedAt == savedAt)
    }

    @Test func savingAgainReplacesThePreviousEntry() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await cache.save(Data(#"{"title":"first"}"#.utf8), savedAt: Date(timeIntervalSince1970: 1))
        try await cache.save(Data(#"{"title":"second"}"#.utf8), savedAt: Date(timeIntervalSince1970: 2))

        let loaded = try #require(await cache.load())

        #expect(loaded.data == Data(#"{"title":"second"}"#.utf8))
        #expect(loaded.savedAt == Date(timeIntervalSince1970: 2))
    }
}
