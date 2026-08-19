import Foundation
import CryptoKit

/// RFC 7636 PKCE, the app's half: generate a random verifier and its S256 challenge.
///
/// The verifier never leaves the device until the WKWebView posts it to `complete`; only the
/// challenge travels in the start URL. That is what makes a one-time code stolen from the callback
/// useless -- redeeming it needs the verifier this app kept.
enum MobileAuthPkce {
    struct Pair: Equatable, Sendable {
        let verifier: String
        let challenge: String
    }

    /// A fresh pair: a 32-byte verifier, base64url without padding, and its SHA-256 challenge.
    static func generate() -> Pair {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = base64URL(Data(bytes))
        return Pair(verifier: verifier, challenge: challenge(for: verifier))
    }

    /// The S256 challenge for a verifier: base64url(SHA-256(verifier)), no padding.
    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    /// A cryptographically random `state`, 32 bytes base64url -- the nonce a callback is matched on.
    static func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
