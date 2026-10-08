# CI/CD

## Workflows

- `.github/workflows/ci.yml`: builds the app without signing on pull requests,
  pushes to `main`, and manual runs. It uploads an unsigned `.app.zip` and
  `.dmg` for smoke testing.
- `.github/workflows/release.yml`: runs for a `vX.Y.Z` tag. It imports the
  Developer ID certificate into an ephemeral keychain, builds the app, signs
  and notarizes both distributable forms, staples the notarization ticket, and
  publishes a GitHub Release.

All reusable GitHub Actions are pinned to immutable commit SHAs.

## Required repository secrets

| Secret | Purpose |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer team owning the App ID and certificate. |
| `MACOS_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application `.p12`. |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting that `.p12`. |
| `APPLE_API_KEY_ID` | App Store Connect API key ID used by `notarytool`. |
| `APPLE_API_ISSUER_ID` | App Store Connect issuer ID. |
| `APPLE_API_PRIVATE_KEY_BASE64` | Base64-encoded `.p8` private key. |

Secrets never belong in the repository, build artifacts, logs, or release
notes. The CI keychain and decoded credential files are deleted by the hosted
runner after the job.

## Release procedure

1. Ensure `make ci` succeeds on `main`.
2. Create and push a semantic version tag, for example `v1.0.0`.
3. The release workflow sets the app version from the tag and the build number
   from `github.run_number`.
4. Verify the workflow's codesign, notarization, stapling, and Gatekeeper
   checks before sharing the generated Release URL.

The in-app updater reads GitHub's `releases/latest` endpoint, so draft and
prerelease entries do not notify normal users.

## Verified baseline

- CI run `37758721111` built the initial Universal app and uploaded unsigned
  `.app.zip` and `.dmg` artifacts.
- Signed Release run `37776527578` published `v1.0.0` after Developer ID
  signing, App and DMG notarization, stapling, and Gatekeeper assessment.
- Both published assets were downloaded again and passed local `codesign`,
  `stapler`, and `spctl` verification. The app contains `arm64` and `x86_64`
  slices and uses bundle ID `com.ifuryst.imacswitch`.
