import Foundation
import Testing
@testable import HSclubs

@Suite(.serialized)
struct LiveSchoolsAPITests {
    private static let expectedHost = "clubs.example.test"

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeAPI(session: URLSession, maxResponseBytes: Int = LiveSchoolsAPI.defaultMaxResponseBytes) -> LiveSchoolsAPI {
        LiveSchoolsAPI(
            baseURL: URL(string: "https://\(Self.expectedHost)")!,
            expectedHost: Self.expectedHost,
            session: session,
            maxResponseBytes: maxResponseBytes
        )
    }

    @Test func fetchesSchoolsPageDataOnSuccess() async throws {
        let body = Data(#"{"title":"HS Clubs"}"#.utf8)
        StubURLProtocol.setStub(.init(statusCode: 200, headers: [:], body: body, error: nil))
        defer { StubURLProtocol.setStub(nil) }

        let api = makeAPI(session: makeSession())
        let data = try await api.fetchSchoolsPageData()

        #expect(data == body)
    }

    @Test func rejectsInsecureBaseURL() async {
        let api = LiveSchoolsAPI(
            baseURL: URL(string: "http://\(Self.expectedHost)")!,
            expectedHost: Self.expectedHost,
            session: makeSession()
        )

        await #expect(throws: SchoolsAPIError.insecureBaseURL) {
            try await api.fetchSchoolsPageData()
        }
    }

    @Test func rejectsUnexpectedHost() async {
        let api = LiveSchoolsAPI(
            baseURL: URL(string: "https://impostor.example")!,
            expectedHost: Self.expectedHost,
            session: makeSession()
        )

        await #expect(throws: SchoolsAPIError.unexpectedHost("impostor.example")) {
            try await api.fetchSchoolsPageData()
        }
    }

    @Test func mapsNonHTTPStatusCodeToError() async {
        StubURLProtocol.setStub(.init(statusCode: 503, headers: [:], body: Data(), error: nil))
        defer { StubURLProtocol.setStub(nil) }

        let api = makeAPI(session: makeSession())

        await #expect(throws: SchoolsAPIError.httpStatus(503)) {
            try await api.fetchSchoolsPageData()
        }
    }

    @Test func mapsTransportFailureToError() async {
        StubURLProtocol.setStub(.init(statusCode: 200, headers: [:], body: Data(), error: URLError(.notConnectedToInternet)))
        defer { StubURLProtocol.setStub(nil) }

        let api = makeAPI(session: makeSession())

        do {
            _ = try await api.fetchSchoolsPageData()
            Issue.record("expected fetchSchoolsPageData to throw")
        } catch let error as SchoolsAPIError {
            guard case .transport = error else {
                Issue.record("expected .transport, got \(error)")
                return
            }
        } catch {
            Issue.record("expected SchoolsAPIError, got \(error)")
        }
    }

    @Test func mapsNonHTTPResponseToError() async {
        StubURLProtocol.setStub(.init(statusCode: 200, headers: [:], body: Data(), error: nil, useNonHTTPResponse: true))
        defer { StubURLProtocol.setStub(nil) }

        let api = makeAPI(session: makeSession())

        await #expect(throws: SchoolsAPIError.nonHTTPResponse) {
            try await api.fetchSchoolsPageData()
        }
    }

    @Test func rejectsResponsesLargerThanMaxSize() async {
        let oversizedBody = Data(repeating: 0x41, count: 20)
        StubURLProtocol.setStub(.init(statusCode: 200, headers: [:], body: oversizedBody, error: nil))
        defer { StubURLProtocol.setStub(nil) }

        let api = makeAPI(session: makeSession(), maxResponseBytes: 10)

        await #expect(throws: SchoolsAPIError.responseTooLarge) {
            try await api.fetchSchoolsPageData()
        }
    }
}
