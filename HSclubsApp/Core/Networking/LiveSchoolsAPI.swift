import Foundation

actor LiveSchoolsAPI: SchoolsAPI {
    static let defaultMaxResponseBytes = 2 * 1024 * 1024

    private let endpoint: URL
    private let expectedHost: String
    private let session: URLSession
    private let maxResponseBytes: Int

    init(
        baseURL: URL,
        expectedHost: String,
        session: URLSession = .shared,
        maxResponseBytes: Int = LiveSchoolsAPI.defaultMaxResponseBytes
    ) {
        self.endpoint = baseURL.appendingPathComponent("api/schools")
        self.expectedHost = expectedHost
        self.session = session
        self.maxResponseBytes = maxResponseBytes
    }

    func fetchSchoolsPageData() async throws -> Data {
        guard endpoint.scheme == "https" else {
            throw SchoolsAPIError.insecureBaseURL
        }
        guard endpoint.host == expectedHost else {
            throw SchoolsAPIError.unexpectedHost(endpoint.host ?? "")
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let byteStream: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (byteStream, response) = try await session.bytes(for: request)
        } catch {
            throw SchoolsAPIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SchoolsAPIError.nonHTTPResponse
        }
        guard
            httpResponse.url?.scheme == "https",
            httpResponse.url?.host?.caseInsensitiveCompare(expectedHost) == .orderedSame
        else {
            throw SchoolsAPIError.unexpectedHost(httpResponse.url?.host ?? "")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SchoolsAPIError.httpStatus(httpResponse.statusCode)
        }

        var data = Data()
        do {
            for try await byte in byteStream {
                data.append(byte)
                if data.count > maxResponseBytes {
                    throw SchoolsAPIError.responseTooLarge
                }
            }
        } catch let error as SchoolsAPIError {
            throw error
        } catch {
            throw SchoolsAPIError.transport(error.localizedDescription)
        }

        return data
    }
}
