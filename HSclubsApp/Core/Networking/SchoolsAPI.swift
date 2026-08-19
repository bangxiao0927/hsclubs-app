import Foundation

protocol SchoolsAPI: Sendable {
    func fetchDirectoryData() async throws -> Data
}

enum SchoolsAPIError: Error, Sendable, Equatable {
    case insecureBaseURL
    case unexpectedHost(String)
    case nonHTTPResponse
    case httpStatus(Int)
    case responseTooLarge
    case invalidData
    case transport(String)
}
