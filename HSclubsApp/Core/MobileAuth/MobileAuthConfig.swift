import Foundation

/// Fixed values the mobile-auth flow depends on, in one place so the app and its tests agree.
enum MobileAuthConfig {
    /// The protocol version marker added to the school web view's user agent.
    ///
    /// It only advertises that the app can drive mobile auth; the school must never treat the UA
    /// as a credential (see contracts/v1/README.md), so it carries a version and nothing secret.
    static let userAgentMarker = "HSclubsApp/1 (mobile-auth/1)"

    /// The one official return channel, matched exactly before a callback is trusted.
    static let callbackHost = "clubs.bangxiao.net"
    static let callbackPath = "/mobile-auth/callback"

    static var callbackURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = callbackHost
        components.path = callbackPath
        return components.url!
    }

    /// The fixed sign-in entry the app intercepts on a verified school origin.
    static let startPath = "/api/mobile-auth/start"
}
