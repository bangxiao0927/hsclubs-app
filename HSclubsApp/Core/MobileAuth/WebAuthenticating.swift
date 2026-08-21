import Foundation
import AuthenticationServices
import UIKit

/// Runs the system sign-in sheet and returns the callback URL, or why it did not.
///
/// A protocol so the login state machine can be tested against a controllable double: the real
/// implementation is a modal `ASWebAuthenticationSession` that no unit test can drive.
@MainActor
protocol WebAuthenticating: Sendable {
    func authenticate(startURL: URL) async -> Result<URL, WebAuthenticationError>
}

enum WebAuthenticationError: Error, Equatable, Sendable {
    case cancelled
    case timedOut
    case failed(String)
}

/// The real runner: `ASWebAuthenticationSession` with the official Universal Link callback.
///
/// The system browser -- not a WKWebView -- performs the sign-in, which is what the identity
/// provider requires and what keeps the app from ever seeing the person's Google credentials. The
/// https callback needs iOS 17.4; on older systems the flow reports itself unavailable rather than
/// falling back to an embedded web view, which is exactly the fallback this design forbids.
@MainActor
final class ASWebAuthenticationRunner: NSObject, WebAuthenticating {
    func authenticate(startURL: URL) async -> Result<URL, WebAuthenticationError> {
        guard #available(iOS 17.4, *) else {
            return .failure(.failed("Mobile sign-in requires iOS 17.4 or later."))
        }
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: startURL,
                callback: .https(host: MobileAuthConfig.callbackHost, path: MobileAuthConfig.callbackPath)
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: .success(callbackURL))
                    return
                }
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                continuation.resume(returning: .failure(.failed(error?.localizedDescription ?? "Sign-in failed.")))
            }
            session.presentationContextProvider = self
            // A code lives ~a minute; the sheet should not linger far past that, but the person may
            // need to type a password, so the app does not impose its own tight timeout here --
            // .timedOut is reserved for the completion step.
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(returning: .failure(.failed("Sign-in could not start.")))
            }
        }
    }
}

extension ASWebAuthenticationRunner: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // The active foreground window; the sheet is presented over whatever the person was on.
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
