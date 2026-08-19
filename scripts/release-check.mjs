#!/usr/bin/env node
// The release gate for shipping the app: every real school must pass the checks the app depends
// on before a build goes out. Demo schools are listed but never gate authentication -- a fixture
// must not be able to hold up a release, and it is not something a person signs into.
//
// Run against production by default, or set HSCLUBS_GUIDE_ORIGIN to point elsewhere. This is wired
// into the scheduled release-gate workflow, never into pull requests: a school's own outage must
// not turn an unrelated PR red.
import process from 'node:process'

const guideOrigin = process.env.HSCLUBS_GUIDE_ORIGIN ?? 'https://clubs.bangxiao.net'
const officialCallback = 'https://clubs.bangxiao.net/mobile-auth/callback'

const problems = []
const fail = (school, message) => problems.push(`${school}: ${message}`)

const getJson = async (url) => {
  const response = await fetch(url, { headers: { accept: 'application/json' } })
  if (!response.ok) throw new Error(`${url} answered ${response.status}`)
  return response.json()
}

// The Universal Link association must name the production app and the callback path.
const checkAppSiteAssociation = async () => {
  try {
    const aasa = await getJson(`${guideOrigin}/.well-known/apple-app-site-association`)
    const details = aasa?.applinks?.details ?? []
    const paths = details.flatMap((d) => (d.components ?? []).map((c) => c['/']))
    if (!paths.includes('/mobile-auth/callback')) {
      problems.push('AASA: does not map /mobile-auth/callback')
    }
    if (!details.some((d) => (d.appIDs ?? []).length > 0)) {
      problems.push('AASA: names no app id')
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

  // Manifest: identity agrees, mobile auth declared, official callback.
  let manifest
  try {
    manifest = await getJson(`${school.siteOrigin}/.well-known/hsclubs-app.json`)
  } catch (error) {
    fail(label, `manifest unreachable: ${error.message}`)
    return
  }
  if (manifest.schoolId !== school.schoolId) fail(label, 'manifest schoolId disagrees with the directory')
  if (!(manifest.capabilities ?? []).includes('mobile-auth.v1')) fail(label, 'manifest does not declare mobile-auth.v1')
  if (manifest.auth?.mobile?.supported !== true) fail(label, 'manifest does not support mobile auth')
  if (manifest.auth?.mobile?.callbackUrl !== officialCallback) fail(label, 'manifest callback is not the official Universal Link')

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

  await checkAppSiteAssociation()
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
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
