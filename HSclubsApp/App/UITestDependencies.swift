#if DEBUG
import Foundation

struct UITestSchoolsAPI: SchoolsAPI {
    static let empty = UITestSchoolsAPI(data: Data("""
        {
          "title": "HS Clubs",
          "generatedAt": "2024-05-01T12:00:00Z",
          "totals": { "schools": 0, "clubs": 0, "checkedAge": "just now" },
          "schools": []
        }
        """.utf8))

    static let sample = UITestSchoolsAPI(data: Data("""
        {
          "title": "HS Clubs",
          "generatedAt": "2024-05-01T12:00:00Z",
          "totals": { "schools": 3, "clubs": 30, "checkedAge": "just now" },
          "schools": [
            {
              "slug": "alpha",
              "siteUrl": "https://alpha.example",
              "host": "alpha.example",
              "status": "live",
              "schoolName": "Alpha Academy",
              "clubCount": 10,
              "categories": [
                { "name": "STEM", "count": 5 },
                { "name": "Service", "count": 5 }
              ],
              "lastUpdatedAt": "2024-05-03T12:00:00Z"
            },
            {
              "slug": "beta",
              "siteUrl": "https://clubs.beta.example",
              "host": "clubs.beta.example",
              "status": "live",
              "schoolName": "Beta High",
              "clubCount": 20,
              "categories": [{ "name": "Service", "count": 20 }],
              "lastUpdatedAt": "2024-05-02T12:00:00Z"
            },
            {
              "slug": "gamma",
              "siteUrl": "https://gamma.example",
              "host": "gamma.example",
              "status": "no-data",
              "schoolName": "Gamma School",
              "clubCount": null,
              "categories": [{ "name": "STEM", "count": 1 }],
              "lastUpdatedAt": null
            }
          ]
        }
        """.utf8))

    let data: Data

    func fetchSchoolsPageData() async throws -> Data {
        data
    }
}

actor UITestSchoolsCache: SchoolsCache {
    func save(_ data: Data, savedAt: Date) async throws {}

    func load() async -> CachedSchoolsPageData? {
        nil
    }
}
#endif
