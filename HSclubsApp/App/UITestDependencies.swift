#if DEBUG
import Foundation

struct UITestSchoolsAPI: SchoolsAPI {
    static let empty = UITestSchoolsAPI(data: Data("""
        {
          "contract": "hsclubs.app-directory",
          "version": 1,
          "generatedAt": "2024-05-01T12:00:00Z",
          "schools": []
        }
        """.utf8))

    static let sample = UITestSchoolsAPI(data: Data("""
        {
          "contract": "hsclubs.app-directory",
          "version": 1,
          "generatedAt": "2024-05-01T12:00:00Z",
          "schools": [
            {
              "schoolId": "sch_alphaAAAAAAAAAAAAA",
              "slug": "alpha",
              "name": "Alpha Academy",
              "siteOrigin": "https://alpha.example",
              "host": "alpha.example",
              "demo": false,
              "integrationStatus": "compatible",
              "clubCount": 10,
              "lastUpdatedAt": "2024-05-03T12:00:00Z",
              "mobileAuth": false
            },
            {
              "schoolId": "sch_betaBBBBBBBBBBBBBB",
              "slug": "beta",
              "name": "Beta High",
              "siteOrigin": "https://clubs.beta.example",
              "host": "clubs.beta.example",
              "demo": false,
              "integrationStatus": "degraded",
              "clubCount": 20,
              "lastUpdatedAt": "2024-05-02T12:00:00Z",
              "mobileAuth": false
            },
            {
              "schoolId": "sch_gammaGGGGGGGGGGGGG",
              "slug": "gamma",
              "name": "Gamma School",
              "siteOrigin": "https://gamma.example",
              "host": "gamma.example",
              "demo": false,
              "integrationStatus": "incompatible",
              "unavailableReason": "the school manifest did not match the v1 contract",
              "clubCount": null,
              "lastUpdatedAt": null,
              "mobileAuth": false
            }
          ]
        }
        """.utf8))

    let data: Data

    func fetchDirectoryData() async throws -> Data {
        data
    }
}

actor UITestSchoolsCache: SchoolsCache {
    func save(_ data: Data, savedAt: Date) async throws {}

    func load() async -> CachedDirectoryData? {
        nil
    }
}
#endif
