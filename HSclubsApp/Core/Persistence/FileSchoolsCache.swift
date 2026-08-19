import Foundation

actor FileSchoolsCache: SchoolsCache {
    private struct Envelope: Codable {
        /// The directory contract version this cache holds. A cache written by an older app that
        /// spoke a different contract is discarded on read rather than decoded into today's
        /// model -- a stale schema is a safe thing to throw away, since the next fetch rebuilds it.
        let version: Int
        let savedAt: Date
        let payload: Data
    }

    /// Bumps when the cached contract changes. The filename carries it too, so a v1 cache and a
    /// future v2 cache never read each other's bytes.
    static let contractVersion = 1

    private let fileURL: URL

    init(directory: URL, filename: String = "directory-cache-v1.json") {
        self.fileURL = directory.appendingPathComponent(filename)
    }

    func save(_ data: Data, savedAt: Date) async throws {
        let envelope = Envelope(version: Self.contractVersion, savedAt: savedAt, payload: data)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(envelope)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoded.write(to: fileURL, options: .atomic)
    }

    func load() async -> CachedDirectoryData? {
        guard let raw = try? Data(contentsOf: fileURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(Envelope.self, from: raw) else {
            return nil
        }
        // A cache from a different contract version is not an error: drop it and let the fetch
        // repopulate. Decoding it as if it were current is the actual hazard.
        guard envelope.version == Self.contractVersion else {
            return nil
        }

        return CachedDirectoryData(data: envelope.payload, savedAt: envelope.savedAt)
    }
}
