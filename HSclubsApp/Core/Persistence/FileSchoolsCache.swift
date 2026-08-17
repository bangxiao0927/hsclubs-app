import Foundation

actor FileSchoolsCache: SchoolsCache {
    private struct Envelope: Codable {
        let savedAt: Date
        let payload: Data
    }

    private let fileURL: URL

    init(directory: URL, filename: String = "schools-cache.json") {
        self.fileURL = directory.appendingPathComponent(filename)
    }

    func save(_ data: Data, savedAt: Date) async throws {
        let envelope = Envelope(savedAt: savedAt, payload: data)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(envelope)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoded.write(to: fileURL, options: .atomic)
    }

    func load() async -> CachedSchoolsPageData? {
        guard let raw = try? Data(contentsOf: fileURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(Envelope.self, from: raw) else {
            return nil
        }

        return CachedSchoolsPageData(data: envelope.payload, savedAt: envelope.savedAt)
    }
}
