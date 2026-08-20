import Foundation

/// A parsed mobile-auth Universal Link.
///
/// The one official return channel is `https://hsclubs.net/mobile-auth/callback` -- a
/// Universal Link, never a custom URL scheme another app could register. The provider hands back
/// exactly one of a one-time `code` or an `error`, alongside the `schoolId` and the `state` the
/// app generated. Nothing here is ever logged: the code is a live credential for ~a minute, and
/// `state` and `schoolId` identify a sign-in in flight.
///
/// See contracts/v1/schemas/mobile-auth-callback.schema.json.
struct MobileAuthCallback: Equatable, Sendable {
    enum Payload: Equatable, Sendable {
        case code(String)
        case error(String)
    }

    let schoolId: String
    let state: String
    let payload: Payload

    static let officialHost = "hsclubs.net"
    static let callbackPath = "/mobile-auth/callback"

    /// Parses a URL into a callback, or nil if it is not a well-formed callback for this domain.
    ///
    /// Returning nil rather than throwing keeps "this is not our link at all" separate from "this
    /// is our link but the sign-in failed": the first is ignored, the second is a recoverable
    /// error the person sees. Both `code`-and-`error` present and neither present are malformed,
    /// because the provider promises exactly one.
    static func parse(_ url: URL) -> MobileAuthCallback? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "https",
            components.host?.caseInsensitiveCompare(officialHost) == .orderedSame,
            components.path == callbackPath
        else { return nil }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            let matches = items.filter { $0.name == name }
            // A duplicated parameter is ambiguous; refuse rather than pick one.
            guard matches.count == 1, let value = matches.first?.value, !value.isEmpty else { return nil }
            return value
        }

        guard let schoolId = value("schoolId"), let state = value("state") else { return nil }

        let code = value("code")
        let error = value("error")
        switch (code, error) {
        case let (code?, nil):
            return MobileAuthCallback(schoolId: schoolId, state: state, payload: .code(code))
        case let (nil, error?):
            return MobileAuthCallback(schoolId: schoolId, state: state, payload: .error(error))
        default:
            // Both or neither: not a callback this app will act on.
            return nil
        }
    }

    /// Parses the web-browsing user activity a Universal Link arrives on, for cold start and
    /// foreground alike.
    static func parse(_ activity: NSUserActivity) -> MobileAuthCallback? {
        guard
            activity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = activity.webpageURL
        else { return nil }
        return parse(url)
    }
}
