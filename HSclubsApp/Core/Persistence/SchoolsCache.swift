import Foundation

struct CachedSchoolsPageData: Sendable, Equatable {
    let data: Data
    let savedAt: Date
}

protocol SchoolsCache: Sendable {
    func save(_ data: Data, savedAt: Date) async throws
    func load() async -> CachedSchoolsPageData?
}
