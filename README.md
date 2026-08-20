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

- Public data endpoint: `GET https://hsclubs.net/api/schools`
- Reachable over HTTPS today, answering `200 application/json`
- Scope: search by school name or host, pick a school, remember the last one, open that school's
  site full screen, and switch schools
- A school's site comes from `siteUrl` and opens in a full-screen web view once the scheme and
  host have been checked. Links the person taps out to elsewhere go to the system browser;
  cross-origin redirects and form posts belonging to sign-in stay in the web view, because the
  session does.
- `/api/status` is an operations endpoint behind Basic Auth and is not part of this app
- The data is a read-only public summary: no sign-in, no member profiles, no club administration

The picker is native **SwiftUI**. A school's full site carries its own sign-in and management
session, so after the HTTPS and host checks it is handed to a full-screen `WKWebView` and left to
that school's web implementation. The floating switch button can be dragged, parks against an
edge, expands inward to `Switch School` on a tap, and folds back when the page is tapped or after
a moment.

## Suggested stack

- iOS 17+, Xcode 16+, Swift 6
- SwiftUI + Observation, with light MVVM/feature layering
- `URLSession` + `async/await` + `Codable`
- Swift Charts for a school's club-count trend
- XCTest / Swift Testing, with a `URLProtocol` stub for the networking layer
- No third-party dependencies in the first version

## MVP scope

1. Load and show the school total, the club total and when the data was last checked.
2. Show school cards with `live`, `stale`, `no-data` and `demo` states.
3. Search by school name or host; filter by category as an intersection.
4. Sort by name, club count or last update.
5. On the detail screen, show address, categories, trend and data age, and open the school's site
   safely.
6. Pull to refresh, loading/empty/failure states, and a local cache of the last successful load.
7. Dark mode, Dynamic Type, VoiceOver and Reduce Motion.

Out of scope for the MVP: sign-in, push notifications, frequent background refresh, club editing,
school registration and the operations status page.

## Planned layout

```text
HSclubsApp/
  App/                 # entry point and dependency wiring
  Core/
    Models/            # Codable models for the API
    Networking/        # APIClient, error mapping
    Persistence/       # cache of the last successful response
  Features/
    Directory/         # totals, search, filtering, sorting
    SchoolDetails/     # school detail and trend
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
checklist are in [`docs/IOS_DEVELOPMENT_PLAN.md`](docs/IOS_DEVELOPMENT_PLAN.md). Pin and version
the guiding page's `/api/schools` contract before writing the data layer, so the web client and
this app cannot each maintain their own idea of the data.

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
