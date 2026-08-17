import Foundation

struct School: Codable, Sendable, Equatable {
    let slug: String
    let siteUrl: URL?
    let host: String?
    let demo: Bool
    let location: SchoolLocation?
    let status: SchoolStatus
    let schoolName: String
    let address: String?
    let clubCount: Int?
    let categories: [Category]
    let publishedAge: String?
    let changedAge: String?
    let checkedAge: String?
    let publishedAt: Date?
    let lastUpdatedAt: Date?
    let history: [HistoryPoint]
    let trend: Int?
    let lastPolledAt: Date?
    let lastError: String?

    init(
        slug: String,
        siteUrl: URL?,
        host: String?,
        demo: Bool,
        location: SchoolLocation? = nil,
        status: SchoolStatus,
        schoolName: String,
        address: String?,
        clubCount: Int?,
        categories: [Category] = [],
        publishedAge: String?,
        changedAge: String?,
        checkedAge: String?,
        publishedAt: Date?,
        lastUpdatedAt: Date?,
        history: [HistoryPoint] = [],
        trend: Int?,
        lastPolledAt: Date?,
        lastError: String?
    ) {
        self.slug = slug
        self.siteUrl = siteUrl
        self.host = host
        self.demo = demo
        self.location = location
        self.status = status
        self.schoolName = schoolName
        self.address = address
        self.clubCount = clubCount
        self.categories = categories
        self.publishedAge = publishedAge
        self.changedAge = changedAge
        self.checkedAge = checkedAge
        self.publishedAt = publishedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.history = history
        self.trend = trend
        self.lastPolledAt = lastPolledAt
        self.lastError = lastError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = try container.decode(String.self, forKey: .slug)
        siteUrl = try container.decodeIfPresent(URL.self, forKey: .siteUrl)
        host = try container.decodeIfPresent(String.self, forKey: .host)
        demo = try container.decodeIfPresent(Bool.self, forKey: .demo) ?? false
        location = try container.decodeIfPresent(SchoolLocation.self, forKey: .location)
        status = try container.decode(SchoolStatus.self, forKey: .status)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? slug
        address = try container.decodeIfPresent(String.self, forKey: .address)
        clubCount = try container.decodeIfPresent(Int.self, forKey: .clubCount)
        categories = try container.decodeIfPresent([Category].self, forKey: .categories) ?? []
        publishedAge = try container.decodeIfPresent(String.self, forKey: .publishedAge)
        changedAge = try container.decodeIfPresent(String.self, forKey: .changedAge)
        checkedAge = try container.decodeIfPresent(String.self, forKey: .checkedAge)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        history = try container.decodeIfPresent([HistoryPoint].self, forKey: .history) ?? []
        trend = try container.decodeIfPresent(Int.self, forKey: .trend)
        lastPolledAt = try container.decodeIfPresent(Date.self, forKey: .lastPolledAt)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
    }
}

extension School {
    var verifiedSiteURL: URL? {
        guard
            let siteUrl,
            siteUrl.scheme == "https",
            let expectedHost = host,
            siteUrl.host?.caseInsensitiveCompare(expectedHost) == .orderedSame
        else { return nil }
        return siteUrl
    }
}
