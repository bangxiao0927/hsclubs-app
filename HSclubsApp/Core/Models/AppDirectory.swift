import Foundation

/// The decoded v1 app directory.
///
/// `schools` has already had unusable entries dropped: one school with a malformed required
/// field is skipped, and the rest of the directory still loads. That is the contract's isolation
/// rule enforced on the client -- one bad school must never empty the list.
struct AppDirectory: Sendable, Equatable {
    let generatedAt: Date
    let schools: [DirectorySchool]
}

enum AppDirectoryDecoder {
    /// Decodes the directory, skipping any single school that fails rather than the whole body.
    static func decode(_ data: Data) throws -> AppDirectory {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.directoryWithFractionalSeconds.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter.directoryWithoutFractionalSeconds.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO-8601 date string, got \(string)"
            )
        }
        let raw = try decoder.decode(RawDirectory.self, from: data)
        return AppDirectory(generatedAt: raw.generatedAt, schools: raw.schools.compactMap(\.value))
    }

    private struct RawDirectory: Decodable {
        let generatedAt: Date
        let schools: [Failable<DirectorySchool>]
    }

    /// Decodes to nil instead of throwing, so a bad element does not fail the array around it.
    /// Each array element is handed its own decoder, so swallowing the error here isolates the
    /// element rather than losing the decoder's position.
    private struct Failable<Wrapped: Decodable>: Decodable {
        let value: Wrapped?

        init(from decoder: Decoder) throws {
            value = try? Wrapped(from: decoder)
        }
    }
}

private extension ISO8601DateFormatter {
    static nonisolated(unsafe) let directoryWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static nonisolated(unsafe) let directoryWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
