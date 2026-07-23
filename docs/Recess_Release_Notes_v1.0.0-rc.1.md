# Recess v1.0.0-rc.1 Release Notes

Build metadata: `1.0.0-rc.1+4`

## Release-candidate scope

Recess v1.0.0-rc.1 is the complete offline-first V1 candidate. It includes
local workday scheduling, exact Android Bell delivery, Recess session
lifecycle, History, Fact Engine, Insight Engine v1, Settings, the curated
Exercise Engine, original identity and Bell sounds, and release-polished
accessibility and presentation.

No account, cloud service, analytics, AI, sync, or network dependency is
included.

## Stabilized

- Scheduled Bells fire while Android is locked or idle.
- Quiet Hours skips scheduled and deferred Bells inside same-day and overnight
  ranges without delaying or shifting cadence.
- Resume, reboot, schedule editing, deferral, timezone changes, and
  reconciliation preserve one consistent notification plan.
- Manual Bells remain an explicit immediate action.
- Notification permission and exact-alarm access fail safely when unavailable.
- Upgrade persistence preserves settings, schedule, History, and local facts.

## Validation

- Physical Android validation passed for scheduling, locked-phone delivery,
  Quiet Hours, resume, reboot, reconciliation, deferred Bells, schedule edits,
  and manual Bells.
- Formatting, static analysis, the full Flutter test suite, release APK, release
  App Bundle, and repository integrity checks form the final production gate.
- All 136 automated tests pass and Flutter analysis reports no issues.

## Artifacts

- APK: `build/app/outputs/flutter-apk/app-release.apk`
  - SHA-256: `145C53E724B995FA068FE1A2B77C25E426E9F55E860BD358B313D3BFB3A25A06`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
  - SHA-256: `4FB49860698BF7BA7094F9770C4401CF7C7718AD138DBD775F529570210D3FC1`

Both artifacts were assembled in release mode with version name
`1.0.0-rc.1` and version code `4`. They are unsigned because release signing
credentials are intentionally absent from the repository and this local
checkout. Sign with the approved upload/release key before distribution.

## Known constraints

- iOS compilation and physical-device validation require macOS and Xcode.
- Android distribution signing requires the approved external release
  keystore.
- Missed Recesses are not inferred from ignored notifications because V1 has no
  explicit missed or expired lifecycle fact.
