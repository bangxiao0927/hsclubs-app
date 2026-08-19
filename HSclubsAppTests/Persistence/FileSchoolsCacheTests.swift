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

    // A cache written under a different contract version must be discarded, not decoded into
    // today's model. Writing an envelope with the wrong version stands in for a cache left by an
    // older app.
    @Test func discardsACacheFromADifferentContractVersion() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let stale = Data(#"{"version":0,"savedAt":"2024-01-01T00:00:00Z","payload":"e30="}"#.utf8)
        try stale.write(to: directory.appendingPathComponent("directory-cache-v1.json"))

        #expect(await cache.load() == nil)
    }

    // A cache written by a pre-versioning build has no version field at all, so it fails to
    // decode and is dropped rather than misread.
    @Test func discardsACacheWithNoVersionField() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let legacy = Data(#"{"savedAt":"2024-01-01T00:00:00Z","payload":"e30="}"#.utf8)
        try legacy.write(to: directory.appendingPathComponent("directory-cache-v1.json"))

        #expect(await cache.load() == nil)
    }
}
