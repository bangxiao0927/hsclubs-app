import Foundation

struct CachedDirectoryData: Sendable, Equatable {
    let data: Data
    let savedAt: Date
}

protocol SchoolsCache: Sendable {
    func save(_ data: Data, savedAt: Date) async throws
    func load() async -> CachedDirectoryData?
}
