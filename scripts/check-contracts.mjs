#!/usr/bin/env node
// Proves this app's copy of the cross-repository v1 contract is the published one.
//
// contracts/v1 is produced by hsclubs-guiding-page and vendored here so the app decodes exactly
// what the guiding page serves and the school template publishes. Editing the copy to make a
// local expectation pass is the failure this guards against: the three repositories would drift
// apart and a school would quietly stop appearing in the app.
//
// Node rather than Swift on purpose -- this must run on any checkout, including CI without Xcode.
// The app-side decoding tests against these fixtures arrive with the directory migration.
import { createHash } from 'node:crypto'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, join, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'contracts', 'v1')
const manifestFile = join(root, 'manifest.json')

const walk = (dir) =>
  readdirSync(dir).flatMap((entry) => {
    const path = join(dir, entry)
    return statSync(path).isDirectory() ? walk(path) : [path]
  })

// Line endings are normalised before hashing, so a checkout is never mistaken for an edit.
const digestOf = (file) =>
  createHash('sha256').update(readFileSync(file, 'utf8').replaceAll('\r\n', '\n'), 'utf8').digest('hex')

const recorded = JSON.parse(readFileSync(manifestFile, 'utf8')).files
const actual = Object.fromEntries(
  walk(root)
    .filter((file) => file !== manifestFile)
    .map((file) => [relative(root, file).split(sep).join('/'), digestOf(file)]),
)

const problems = [
  ...Object.keys(actual).filter((file) => !(file in recorded)).map((file) => `${file}: not in manifest.json`),
  ...Object.keys(recorded).filter((file) => !(file in actual)).map((file) => `${file}: missing from this copy`),
  ...Object.keys(actual)
    .filter((file) => file in recorded && recorded[file] !== actual[file])
    .map((file) => `${file}: content differs from the published contract`),
]

if (problems.length > 0) {
  for (const problem of problems) console.error(problem)
  console.error(
    'Edit contracts/ in hsclubs-guiding-page and copy the directory over; do not edit the vendored copy.',
  )
  process.exit(1)
}

console.log(`contracts v1: ${Object.keys(actual).length} files match manifest.json`)
