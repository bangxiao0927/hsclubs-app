import Foundation

final class StubURLProtocol: URLProtocol {
    struct Stub: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
        let error: Error?
        var useNonHTTPResponse: Bool = false
    }

    private struct Storage: @unchecked Sendable {
        var stub: Stub?
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var storage = Storage()

    static func setStub(_ stub: Stub?) {
        lock.lock()
        storage.stub = stub
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let stub = Self.storage.stub
        Self.lock.unlock()

        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if stub.useNonHTTPResponse {
            let response = URLResponse(
                url: request.url!,
                mimeType: "application/json",
                expectedContentLength: stub.body.count,
                textEncodingName: nil
            )
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
