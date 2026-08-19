import Foundation

/// One school in the v1 app directory (`GET /api/v1/schools`).
///
/// This is the whole of what the app needs to list a school and open it: identity, a display
/// name, the verified origin, the host, whether mobile auth is available, and a status. It is
/// deliberately narrower than the browser payload the guiding page also serves -- no history,
/// trend or category breakdown -- so a later change to one of those fields cannot force an app
/// release. See contracts/v1/schemas/app-directory.schema.json.
///
/// Decoding is loss-tolerant on two axes. Unknown members are ignored, so a newer guiding page
/// may add fields without breaking this build; and a member the app does not require that is
/// present but malformed falls back to its default rather than failing the school. The required
/// members -- the ones the app cannot render a row without -- are the only ones whose absence
/// throws, and a throw skips just that one school (see `AppDirectory`).
struct DirectorySchool: Sendable, Equatable, Identifiable {
    /// Whether the guiding page found this school's v1 integration usable.
    ///
    /// A closed set in the contract, but decoded tolerantly: a value this build has not learned
    /// yet becomes `.unknown` and is treated as not-openable rather than crashing the decode.
    enum IntegrationStatus: Sendable, Equatable {
        case compatible
        case degraded
        case incompatible
        case unknown(String)

        init(rawValue: String) {
            switch rawValue {
            case "compatible": self = .compatible
            case "degraded": self = .degraded
            case "incompatible": self = .incompatible
            default: self = .unknown(rawValue)
            }
        }
    }

    let schoolId: String
    let slug: String
    let name: String
    let shortName: String?
    let siteOrigin: URL
    let host: String
    let demo: Bool
    let integrationStatus: IntegrationStatus
    let unavailableReason: String?
    let clubCount: Int?
    let lastUpdatedAt: Date?
    let mobileAuth: Bool

    var id: String { schoolId }

    /// Openable schools: compatible or degraded. An incompatible or unrecognised status is shown
    /// but never navigated to, so a misconfigured school is visible without being a trap.
    var isEnterable: Bool {
        switch integrationStatus {
        case .compatible, .degraded: return true
        case .incompatible, .unknown: return false
        }
    }

    /// The URL to open, or nil.
    ///
    /// Re-checks the origin the guiding page already verified rather than trusting it blindly: an
    /// app that navigates a `WKWebView` to whatever a JSON field says is one bad directory away
    /// from opening someone else's site. HTTPS, and the origin's host must be the declared host.
    var enterableURL: URL? {
        guard
            isEnterable,
            siteOrigin.scheme == "https",
            siteOrigin.host?.caseInsensitiveCompare(host) == .orderedSame
        else { return nil }
        return siteOrigin
    }
}

extension DirectorySchool: Decodable {
    private enum CodingKeys: String, CodingKey {
        case schoolId, slug, name, shortName, siteOrigin, host, demo
        case integrationStatus, unavailableReason, clubCount, lastUpdatedAt, mobileAuth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required: a row cannot be drawn or opened without these, so a school missing any of
        // them is skipped rather than shown half-built.
        schoolId = try container.decode(String.self, forKey: .schoolId)
        slug = try container.decode(String.self, forKey: .slug)
        name = try container.decode(String.self, forKey: .name)
        let originString = try container.decode(String.self, forKey: .siteOrigin)
        guard let origin = URL(string: originString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .siteOrigin,
                in: container,
                debugDescription: "siteOrigin is not a URL: \(originString)"
            )
        }
        siteOrigin = origin
        host = try container.decode(String.self, forKey: .host)
        integrationStatus = IntegrationStatus(
            rawValue: try container.decode(String.self, forKey: .integrationStatus)
        )

        // Optional and defaulted: a malformed value here degrades the row, never drops the school.
        shortName = try? container.decodeIfPresent(String.self, forKey: .shortName)
        demo = (try? container.decodeIfPresent(Bool.self, forKey: .demo)) ?? false
        unavailableReason = try? container.decodeIfPresent(String.self, forKey: .unavailableReason)
        clubCount = try? container.decodeIfPresent(Int.self, forKey: .clubCount)
        lastUpdatedAt = try? container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        mobileAuth = (try? container.decodeIfPresent(Bool.self, forKey: .mobileAuth)) ?? false
    }
}
