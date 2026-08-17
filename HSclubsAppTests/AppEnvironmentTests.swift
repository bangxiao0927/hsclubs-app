import Foundation
import Testing
@testable import HSclubs

struct AppEnvironmentTests {
    @Test func configuredAPIUsesHTTPS() {
        #expect(AppEnvironment.apiBaseURL.scheme == "https")
    }
}
