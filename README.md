# HSclubs iOS

[中文](README.zh-CN.md)

HSclubs iOS is the school switcher for the
[HSclubs Guiding Page](https://hsclubs.net). Somebody searches for a verified school,
picks it, and the app opens that school's own site full screen.

> Status: the trimmed school picker, the production API, the offline cache, the full-screen
> school site, remembering the last school and the floating switcher are done. What comes next is
> in the [iOS development plan](docs/IOS_DEVELOPMENT_PLAN.md).

## What the guiding page actually is

A read-only aggregator. Its server polls each school's public summary on a schedule, so this app
reads the aggregate and nothing else: it must not poll schools directly, and it does not need a
copy of the Node.js poller.

- App directory endpoint: `GET https://hsclubs.net/api/v1/schools`
- Reachable over HTTPS today, answering `200 application/json`
- Scope: search by school name or host, pick a school, remember the last one, open that school's
  site full screen, and switch schools
- A school's site comes from `siteOrigin` and opens in a full-screen web view once the scheme and
  full origin have been checked. Same-origin navigation stays in the web view, ordinary external
  links open in Safari, and non-user cross-origin navigation is refused.
- `/api/status` is an operations endpoint behind Basic Auth and is not part of this app
- The directory is public and contains no member profile or club-administration data

The picker is native **SwiftUI**. A school's full site carries its own sign-in and management
session, so after the HTTPS and host checks it is handed to a full-screen `WKWebView` and left to
that school's web implementation. The floating switch button can be dragged, parks against an
edge, expands inward to `Switch School` on a tap, and folds back when the page is tapped or after
a moment.

## Suggested stack

- iOS 17+, Xcode 16+, Swift 6
- iPhone only; the switcher and full-screen school site are designed for one-handed phone use
- SwiftUI + Observation, with light MVVM/feature layering
- `URLSession` + `async/await` + `Codable`
- XCTest / Swift Testing, with a `URLProtocol` stub for the networking layer
- No third-party dependencies in the first version

## MVP scope

1. Show one native school/host search field followed by verified schools.
2. Open the selected school's verified origin directly in a full-screen `WKWebView`.
3. Remember the selection by immutable `schoolId` and reopen it on the next launch.
4. Provide the draggable, edge-snapping floating school switcher without a persistent header.
5. Pull to refresh, loading/empty/failure states, and a local cache of the last successful load.
6. Keep malformed schools isolated and show incompatible schools without allowing entry.

The app collects nothing and ships a privacy manifest saying so: no tracking, no collected data,
and `UserDefaults` declared under `CA92.1` for remembering the chosen school.

Mobile authentication code exists but is disabled in every build configuration. It stays off until
the production Apple App ID, AASA association, all-real-school readiness check and device E2E are
available. Push notifications, background polling, native school details, club editing, school
registration and the operations status page are outside the MVP.

## Planned layout

```text
HSclubsApp/
  App/                 # entry point and dependency wiring
  Core/
    Models/            # Codable models for the API
    Networking/        # APIClient, error mapping
    Persistence/       # cache of the last successful response
  Features/
    Directory/         # minimal school/host search and selection
    SchoolDetails/     # full-screen school site and floating switcher
  DesignSystem/        # colours, type, shared components
HSclubsAppTests/
HSclubsAppUITests/
```

## Getting started

1. Open `HSclubs.xcodeproj` with Xcode 16 or newer.
2. Pick the shared `HSclubs` scheme and any iOS 17+ simulator, then run.
3. After editing `project.yml`, run `xcodegen generate` to regenerate the project.

From the command line:

```bash
xcodebuild -project HSclubs.xcodeproj \
  -scheme HSclubs \
  -configuration Development \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The service address for `Development`, `Staging` and `Production` is injected by the matching
`.xcconfig` under `Configurations/`. The full steps, acceptance criteria, tests and submission
checklist are in [`docs/IOS_DEVELOPMENT_PLAN.md`](docs/IOS_DEVELOPMENT_PLAN.md). The app consumes
the pinned, loss-tolerant v1 directory instead of coupling itself to the browser payload.

The app reads the guiding page's aggregate and never polls a school directly. While developing,
`python3 scripts/verify_guide_data.py` reads a real school's authoritative `/api/summary` and
checks the identity, club total, categories and publication time the aggregate reports; demo
schools serve saved data and are skipped explicitly. Where a school's own deployment ends and
this app begins is described in [`docs/SYNC_ARCHITECTURE.md`](docs/SYNC_ARCHITECTURE.md).

## Cross-repository contract

`contracts/v1/` is the v1 contract this app, the guiding page and the school template share. It is
published by [hsclubs-guiding-page](https://github.com/bangxiao0927/hsclubs-guiding-page) and
copied here verbatim: JSON Schemas for `/api/v1/summary`, `/.well-known/hsclubs-app.json` and
`/api/v1/schools`, pinned fixtures, and the PKCE and one-time code vectors for mobile
authentication. It is documented in [`contracts/v1/README.md`](contracts/v1/README.md).

```bash
node scripts/check-contracts.mjs
```

That script compares the sha-256 of every file here against `manifest.json`, and runs in CI. The
contract is edited upstream and the directory copied over; editing this copy is how three
repositories quietly stop agreeing. The Swift-side decoding tests against these fixtures arrive
with the directory migration.

## Licence

[Apache License 2.0](LICENSE).
