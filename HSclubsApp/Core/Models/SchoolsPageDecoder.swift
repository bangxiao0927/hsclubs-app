import Foundation

enum SchoolsPageDecoder {
    static func decode(_ data: Data) throws -> PagePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = ISO8601DateFormatter.schoolsWithFractionalSeconds.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter.schoolsWithoutFractionalSeconds.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO-8601 date string, got \(string)"
            )
        }
        return try decoder.decode(PagePayload.self, from: data)
    }
}

private extension ISO8601DateFormatter {
    static nonisolated(unsafe) let schoolsWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static nonisolated(unsafe) let schoolsWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
