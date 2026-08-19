import Foundation
import Observation

@MainActor
@Observable
final class DirectoryViewModel {
    private let repository: SchoolsRepository
    private var hasLoaded = false

    private(set) var directory: AppDirectory?
    private(set) var cachedAt: Date?
    private(set) var errorMessage: String?
    private(set) var isLoading = true
    private(set) var isRefreshing = false
    var query = ""

    init(repository: SchoolsRepository) {
        self.repository = repository
    }

    var schools: [DirectorySchool] {
        DirectoryQuery.sortedByName(
            DirectoryQuery.search(directory?.schools ?? [], query: query)
        )
    }

    func clearSearch() {
        query = ""
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await load()
    }

    func refresh() async {
        guard !isLoading, !isRefreshing else { return }
        await load()
    }

    private func load() async {
        isLoading = directory == nil
        isRefreshing = directory != nil
        errorMessage = nil

        var pendingCache: (directory: AppDirectory, savedAt: Date)?
        let events = await repository.events()
        for await event in events {
            switch event {
            case .cacheLoaded(let cachedDirectory, let savedAt):
                pendingCache = (cachedDirectory, savedAt)
                if directory == nil {
                    directory = cachedDirectory
                    cachedAt = savedAt
                    isLoading = false
                    isRefreshing = true
                }
            case .networkSucceeded(let freshDirectory):
                directory = freshDirectory
                cachedAt = nil
                errorMessage = nil
            case .networkFailed(let error):
                if directory == nil, let pendingCache {
                    directory = pendingCache.directory
                }
                if let pendingCache {
                    cachedAt = pendingCache.savedAt
                }
                errorMessage = error.userMessage(hasCachedData: directory != nil)
            }
        }

        isLoading = false
        isRefreshing = false
    }
}

private extension SchoolsAPIError {
    func userMessage(hasCachedData: Bool) -> String {
        let prefix = hasCachedData ? "Showing saved data. " : ""
        switch self {
        case .transport:
            return prefix + "Check your connection and try again."
        case .httpStatus:
            return prefix + "The directory service is temporarily unavailable."
        case .responseTooLarge, .invalidData, .nonHTTPResponse, .insecureBaseURL, .unexpectedHost:
            return prefix + "The directory response could not be verified."
        }
    }
}
