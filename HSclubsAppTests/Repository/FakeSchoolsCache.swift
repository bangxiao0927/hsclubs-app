import Foundation
@testable import HSclubs

actor FakeSchoolsCache: SchoolsCache {
    private var stored: CachedSchoolsPageData?

    init(stored: CachedSchoolsPageData? = nil) {
        self.stored = stored
    }

    func save(_ data: Data, savedAt: Date) async throws {
        stored = CachedSchoolsPageData(data: data, savedAt: savedAt)
    }

    func load() async -> CachedSchoolsPageData? {
        stored
    }

    func currentValue() async -> CachedSchoolsPageData? {
        stored
    }
}
