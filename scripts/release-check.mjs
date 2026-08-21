#!/usr/bin/env node
// The release gate for shipping the app: every real school must pass the checks the app depends
// on before a build goes out. Demo schools are listed but never gate authentication -- a fixture
// must not be able to hold up a release, and it is not something a person signs into.
//
// Run against production by default, or set HSCLUBS_GUIDE_ORIGIN to point elsewhere. This is wired
// into the scheduled release-gate workflow, never into pull requests: a school's own outage must
// not turn an unrelated PR red.
import process from 'node:process'

const guideOrigin = process.env.HSCLUBS_GUIDE_ORIGIN?.trim() || 'https://hsclubs.net'
const requireMobileAuth = process.env.HSCLUBS_REQUIRE_MOBILE_AUTH === 'true'
const officialCallback = 'https://hsclubs.net/mobile-auth/callback'

const problems = []
const fail = (school, message) => problems.push(`${school}: ${message}`)

const getJson = async (url) => {
  const response = await fetch(url, { headers: { accept: 'application/json' } })
  if (!response.ok) throw new Error(`${url} answered ${response.status}`)
  return response.json()
}

// A GET that only needs to reach the server; a redirect counts as reachable.
const reach = async (url) => {
  const response = await fetch(url, { redirect: 'manual' })
  const status = response.status
  return { ok: status < 400 || (status >= 300 && status < 400), status }
}

// The Universal Link association must name the production app and the callback path.
const checkAppSiteAssociation = async () => {
  try {
    const aasa = await getJson(`${guideOrigin}/.well-known/apple-app-site-association`)
    const details = aasa?.applinks?.details ?? []
    const paths = details.flatMap((d) => (d.components ?? []).map((c) => c['/']))
    const appIDs = details.flatMap((d) => d.appIDs ?? [])
    const credentialAppIDs = aasa?.webcredentials?.apps ?? []
    if (!paths.includes('/mobile-auth/callback')) {
      problems.push('AASA: does not map /mobile-auth/callback')
    }
    if (appIDs.length === 0) {
      problems.push('AASA: names no app id')
    }
    if (credentialAppIDs.length === 0) {
      problems.push('AASA: names no app id for web credentials')
    } else if (!appIDs.some((appID) => credentialAppIDs.includes(appID))) {
      problems.push('AASA: app links and web credentials do not name the same app')
    }
  } catch (error) {
    problems.push(`AASA: ${error.message}`)
  }
}

const checkSchool = async (school) => {
  const label = school.slug ?? school.schoolId ?? 'unknown'
  if (school.demo) return // Demo schools are shown but excluded from the auth gate.

  if (school.integrationStatus !== 'compatible') {
    fail(label, `directory status is ${school.integrationStatus}, not compatible`)
    return
  }

  // Manifest identity is required for every app release. Mobile auth is checked only when that
  // separately gated feature is enabled; until then the native app keeps it fail-closed.
  let manifest
  try {
    manifest = await getJson(`${school.siteOrigin}/.well-known/hsclubs-app.json`)
  } catch (error) {
    fail(label, `manifest unreachable: ${error.message}`)
    return
  }
  if (manifest.schoolId !== school.schoolId) fail(label, 'manifest schoolId disagrees with the directory')
  if (requireMobileAuth) {
    if (school.mobileAuth !== true) fail(label, 'directory does not enable mobile auth')
    if (!(manifest.capabilities ?? []).includes('mobile-auth.v1')) fail(label, 'manifest does not declare mobile-auth.v1')
    if (manifest.auth?.mobile?.supported !== true) fail(label, 'manifest does not support mobile auth')
    if (manifest.auth?.mobile?.callbackUrl !== officialCallback) fail(label, 'manifest callback is not the official Universal Link')
  }

  // Root page: the school's own site must load, since the app opens it in a web view.
  try {
    const root = await reach(school.siteOrigin)
    if (!root.ok) fail(label, `root page answered ${root.status}`)
  } catch (error) {
    fail(label, `root page unreachable: ${error.message}`)
  }

  if (requireMobileAuth) {
    // A bare GET proves the endpoint validates input without starting a real sign-in.
    try {
      const response = await fetch(`${school.siteOrigin}/api/mobile-auth/start`, {
        headers: { accept: 'application/json' },
        redirect: 'manual',
      })
      if (response.status < 400) {
        fail(label, `mobile-auth start did not reject an empty request (status ${response.status})`)
      } else {
        const body = await response.json().catch(() => ({}))
        if (body.contract !== 'hsclubs.mobile-auth-error') {
          fail(label, 'mobile-auth start did not answer with the contract error shape')
        }
      }
    } catch (error) {
      fail(label, `mobile-auth start unreachable: ${error.message}`)
    }
  }

  // Summary: identity agrees.
  try {
    const summary = await getJson(`${school.siteOrigin}/api/v1/summary`)
    if (summary.schoolId !== school.schoolId) fail(label, 'summary schoolId disagrees with the directory')
  } catch (error) {
    fail(label, `summary unreachable: ${error.message}`)
  }
}

const main = async () => {
  let directory
  try {
    directory = await getJson(`${guideOrigin}/api/v1/schools`)
  } catch (error) {
    console.error(`Could not read the directory: ${error.message}`)
    process.exit(1)
  }

  if (requireMobileAuth) await checkAppSiteAssociation()
  for (const school of directory.schools ?? []) {
    await checkSchool(school)
  }

  const realSchools = (directory.schools ?? []).filter((s) => !s.demo)
  if (problems.length > 0) {
    console.error('Release gate failed:')
    for (const problem of problems) console.error(`  - ${problem}`)
    process.exit(1)
  }
  console.log(`Release gate passed: ${realSchools.length} real school(s) ready.`)
  if (requireMobileAuth) {
    console.log('Mobile auth prerequisites passed; Google sign-in and WKWebView recovery remain in E2E.')
  } else {
    console.log('Mobile auth is deferred and was not checked; the app runtime flag must remain disabled.')
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
