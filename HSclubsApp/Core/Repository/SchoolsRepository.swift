import Foundation

enum SchoolsRepositoryEvent: Sendable {
    case cacheLoaded(PagePayload, savedAt: Date)
    case networkSucceeded(PagePayload)
    case networkFailed(SchoolsAPIError)
}

actor SchoolsRepository {
    private let api: SchoolsAPI
    private let cache: SchoolsCache
    private let decode: @Sendable (Data) throws -> PagePayload

    init(
        api: SchoolsAPI,
        cache: SchoolsCache,
        decode: @escaping @Sendable (Data) throws -> PagePayload = SchoolsPageDecoder.decode
    ) {
        self.api = api
        self.cache = cache
        self.decode = decode
    }

    func events() -> AsyncStream<SchoolsRepositoryEvent> {
        AsyncStream { continuation in
            let task = Task {
                if let cached = await cache.load(), let payload = try? decode(cached.data) {
                    continuation.yield(.cacheLoaded(payload, savedAt: cached.savedAt))
                }

                do {
                    let data = try await api.fetchSchoolsPageData()
                    let payload: PagePayload
                    do {
                        payload = try decode(data)
                    } catch {
                        throw SchoolsAPIError.invalidData
                    }
                    try? await cache.save(data, savedAt: Date())
                    continuation.yield(.networkSucceeded(payload))
                } catch let error as SchoolsAPIError {
                    continuation.yield(.networkFailed(error))
                } catch {
                    continuation.yield(.networkFailed(.transport(error.localizedDescription)))
                }

                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
