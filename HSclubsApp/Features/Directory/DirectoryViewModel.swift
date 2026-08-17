import Foundation
import Observation

@MainActor
@Observable
final class DirectoryViewModel {
    private let repository: SchoolsRepository
    private var hasLoaded = false

    private(set) var payload: PagePayload?
    private(set) var cachedAt: Date?
    private(set) var errorMessage: String?
    private(set) var isLoading = true
    private(set) var isRefreshing = false
    var query = ""

    init(repository: SchoolsRepository) {
        self.repository = repository
    }

    var schools: [School] {
        DirectoryQuery.sortedByName(
            DirectoryQuery.search(payload?.schools ?? [], query: query)
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
        isLoading = payload == nil
        isRefreshing = payload != nil
        errorMessage = nil

        var pendingCache: (payload: PagePayload, savedAt: Date)?
        let events = await repository.events()
        for await event in events {
            switch event {
            case .cacheLoaded(let cachedPayload, let savedAt):
                pendingCache = (cachedPayload, savedAt)
                if payload == nil {
                    payload = cachedPayload
                    cachedAt = savedAt
                    isLoading = false
                    isRefreshing = true
                }
            case .networkSucceeded(let freshPayload):
                payload = freshPayload
                cachedAt = nil
                errorMessage = nil
            case .networkFailed(let error):
                if payload == nil, let pendingCache {
                    payload = pendingCache.payload
                }
                if let pendingCache {
                    cachedAt = pendingCache.savedAt
                }
                errorMessage = error.userMessage(hasCachedData: payload != nil)
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
