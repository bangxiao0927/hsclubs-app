# Project Preferences

- Keep the native home screen minimal: one school/host search field followed by the schools.
- Selecting a school opens its verified site directly in a full-screen WebView; do not insert a native school summary/detail screen.
- Persist the selected school and reopen it automatically on the next app launch.
- Overlay school sites with a draggable floating switcher that shrinks while dragging and snaps partly to the nearest screen edge.
- Tapping the floating switcher expands an adjacent Switch School panel; tapping elsewhere or waiting collapses it.
- The floating switcher returns to the native school search screen so the user can choose another school.
- Do not show a persistent host/header bar over the school website.
- Disable pinch-to-zoom inside the school website WebView.

## Cross-Repository Architecture

- Use an expand-contract rollout: add versioned v1 contracts and keep legacy APIs until written removal criteria are met.
- Treat registry-issued `schoolId` as the immutable cross-system identity; keep slug as a mutable display/URL attribute.
- Decode the App's minimal v1 school directory loss-tolerantly so one invalid school does not fail the full response.
- Persist selected schools by versioned `schoolId`, with a one-time unique-slug migration from legacy selection data.
- Use Universal Links plus `ASWebAuthenticationSession` for mobile OAuth, then exchange a short-lived, single-use PKCE-bound code for the school's WKWebView session.
- Keep regular website login intact; mobile authentication is a parallel entry point and must not pass OAuth tokens to the App.
- Restrict WKWebView navigation to verified same-origin school content, open ordinary external links in Safari, and route OAuth only through the mobile-auth protocol.
- Do not release the App authentication flow until all real schools are upgraded; Demo schools do not participate in the authentication release gate.
- Keep mobile authentication disabled until the production Apple App ID, AASA association and real-device end-to-end checks are available.
