import Foundation
@testable import HSclubs

actor FakeSchoolsCache: SchoolsCache {
    private var stored: CachedDirectoryData?

    init(stored: CachedDirectoryData? = nil) {
        self.stored = stored
    }

    func save(_ data: Data, savedAt: Date) async throws {
        stored = CachedDirectoryData(data: data, savedAt: savedAt)
    }

    func load() async -> CachedDirectoryData? {
        stored
    }

    func currentValue() async -> CachedDirectoryData? {
        stored
    }
}
