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
        // The versioned directory, not the browser's /api/schools: the app reads the minimal
        // projection meant for it, and stays uncoupled from the fields the web page draws.
        self.endpoint = baseURL.appendingPathComponent("api/v1/schools")
        self.expectedHost = expectedHost
        self.session = session
        self.maxResponseBytes = maxResponseBytes
    }

    func fetchDirectoryData() async throws -> Data {
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
        // A declared length over the cap is refused before a single byte is read; an undeclared
        // or lying length still hits the running check below.
        if httpResponse.expectedContentLength > Int64(maxResponseBytes) {
            throw SchoolsAPIError.responseTooLarge
        }

        // Accumulated in a byte buffer rather than appending to Data per element: the body is
        // still bounded as it arrives (unlike a bulk load, which would buffer an unbounded body
        // before anything could reject it), without a Data copy for every byte.
        var buffer = [UInt8]()
        buffer.reserveCapacity(min(maxResponseBytes, 64 * 1024))
        do {
            for try await byte in byteStream {
                buffer.append(byte)
                if buffer.count > maxResponseBytes {
                    throw SchoolsAPIError.responseTooLarge
                }
            }
        } catch let error as SchoolsAPIError {
            throw error
        } catch {
            throw SchoolsAPIError.transport(error.localizedDescription)
        }

        return Data(buffer)
    }
}
