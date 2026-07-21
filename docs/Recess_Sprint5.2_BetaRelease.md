# Sprint 5.2: Beta Release

## Status

Complete and approved as the current Beta after stable v1.6.1. The release is
`1.7.0-beta.1+2`, tagged `v1.7.0-beta.1`. Version 1.6.1 remains the current
Stable and its canonical documentation remains preserved as history.

## Scope

- Preserved Android package and namespace `com.recessapp.recess` and the matching
  iOS bundle identifier because they are valid and already established.
- Standardized the native application and bundle display name as `Recess`.
- Updated Flutter build metadata to `1.7.0-beta.1+2`; Android and iOS continue to
  derive their versions from Flutter build metadata.
- Added the Beta label only to Settings About and expanded the existing offline
  privacy statement: no account, cloud, analytics, personal-data collection, or
  transmission; settings and history remain on device.
- Replaced white/default Flutter launch surfaces with the Recess cream color.
  The original green Recess bell mark is centered on Android and above the
  native iOS `Recess` wordmark.
- Added an original path-based Recess bell identity, complete Android
  legacy/round/adaptive/monochrome resources, and a complete opaque iOS AppIcon
  set generated from one canonical SVG.
- Replaced all earlier audio bytes with three original, deterministic,
  procedurally synthesized Recess Bell sounds while preserving filenames and
  platform mappings.
- Scheduled Bells use Android exact allow-while-idle delivery so Doze does not
  defer them until the device wakes. The exact-alarm permission and its platform
  special-access request are wired through the existing notification-permission
  flow. Bell times, cadence generation, and session behavior are unchanged.
- Added explicit Android 13 notification permission declaration and retained the
  boot receiver permission used by the existing notification integration.
- Removed debug-key release signing. Android release builds now read an ignored
  local `android/key.properties`; a non-secret example is included.
- Added a database reopen test covering schedule, preferences, and completed
  history with the unchanged schema.

## No product change

This sprint changes packaging, identity surfaces, release configuration,
documentation, and beta-readiness validation only. Scheduler behavior, session
accounting, exercise selection and prescriptions, Fact Engine, Insight Engine,
History, Bell timing, persistence format, and database schema are unchanged.
Quiet Hours remains stored-only and does not affect Bells.

## Release prerequisites and environment limits

1. Android release signing requires a locally held upload key and credentials.
   No secret or key is stored in the repository.
2. iOS signing, launch rendering, device installation, and TestFlight readiness
   require a macOS/Xcode environment and Apple Developer credentials.
3. Android device validation approved the original icon, splash, synthesized
   sounds, upgrade preservation, and locked-phone Bell delivery.

The per-file sources, hashes, modifications, platform locations, and approval
states are recorded in
`Recess_Release_Asset_Manifest_v1.7.0-beta.1.md`.

## Original release assets

- `assets/branding/recess_bell_master.svg` is the canonical identity source,
  using `#315C4B` green and `#F7F3E8` cream.
- `tool/generate_brand_assets.py` deterministically produces the PNG master,
  Android launcher family, complete iOS AppIcon set, and iOS splash image set.
- `tool/generate_bell_sounds.py` produces the three original PCM WAV files from
  mathematical waveforms, deterministic noise, envelopes, and normalization.
- The release asset manifest records construction, properties, hashes, platform
  locations, and first-party provenance.

## Architecture and defaults audit

- No web or desktop platform project exists, so no new platform was added.
- Android minimum, target, and compile SDK values remain Flutter-managed.
- R8/minification and resource shrinking are explicitly disabled for this beta
  release; this avoids changing runtime behavior during packaging validation.
- iOS remains targeted at iOS 13 and declares no unnecessary background modes.
- Original Bell raw resources and iOS sound copies retain the existing names and
  mapping. Bell preview and notification sound behavior are unchanged.
- No account, network client, cloud SDK, analytics SDK, hard-coded secret,
  keystore, or signing password was added.
- No Flutter launcher icon remains active. Android resolves original legacy,
  round, adaptive, and monochrome assets generated from the canonical mark.
- All 19 iOS AppIcon entries resolve to opaque original Recess icons at their
  declared dimensions.
- The legacy iOS `LaunchImage.imageset` contains generated Flutter files but is
  no longer referenced by `LaunchScreen.storyboard`. It is retained as an
  inactive platform-template resource until approved artwork is supplied; the
  active launch screen does not display it.
- There are no superseded Bell recordings outside the three mapped WAV names.
  Three byte-identical platform copies per sound are intentional because
  preview, Android notification, and iOS notification packaging use different
  locations. No tracked asset is unusually large for its role.
- About version values are kept as constants matching `pubspec.yaml`. Runtime
  package metadata was considered, but adding a package only for this label was
  avoided when dependency resolution was unavailable in the validation
  environment.

## Locked-phone Bell regression

Device testing found that `inexactAllowWhileIdle` Bells could be deferred by
Android Doze until Recess was opened. The original Sprint 5.2 permission removal
exposed that the notification implementation was not using exact scheduling.
The fix changes only the Android delivery contract:

- cadence and deferred Bells now use `exactAllowWhileIdle`;
- `SCHEDULE_EXACT_ALARM` is declared again;
- the existing notification permission flow checks exact-alarm access and opens
  Android's app-specific access screen when it is missing;
- direct method-channel tests verify both the schedule mode and permission flow.

Existing configured beta installations should toggle Notifications off and on
once after upgrading so Android can grant exact-alarm access, then reopen Recess
or save the Workday so pending Bells are rebuilt with exact delivery. This is
not needed when access is already granted. Manual Bells and iOS delivery are
unchanged.

## Upgrade expectation

Because the application identifiers and schema are unchanged, installing the
beta over v1.6.1 should preserve workday configuration, preferences, history,
and the completed-session facts consumed by Insights. Normal upgrades should not
clear app data. Android notification channels can cache sound resources; clear
app data or reinstall only when explicitly retesting changed channel sounds.

## Documentation state

The v1.7.0-beta.1 DOCX set, this implementation record, release checklist, and
release asset manifest are canonical for the current Beta. Version 1.6.1
remains the current Stable and its documentation files remain unchanged.

## Validation record

- `dart format --output=none --set-exit-if-changed lib test`: passed, 42 files
  unchanged on the final run.
- `flutter analyze`: passed with no issues.
- Focused persistence, Bell mapping, manual/scheduled Bell, and session tests:
  passed, 31 tests.
- Full `flutter test --concurrency=1`: passed, 125 tests, including exact-alarm
  schedule mode, permission flow, original masters, complete icon families, and
  native splash coverage. A prior parallel run
  had one worker connection close before loading; the serial rerun was clean.
- `flutter build bundle`: passed.
- `flutter build apk --debug`: passed; the artifact is
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Release APK and AAB assembly reached Gradle dependency resolution but remains
  blocked by the existing Java trust-store error: `PKIX path building failed`
  while fetching Flutter/Android artifacts from Google and Maven repositories.
  This is an environment certificate-chain failure, not an application-code or
  signing-configuration failure.
- The Android build reports a future-compatibility warning because
  `flutter_timezone` still applies the Kotlin Gradle Plugin. It does not fail the
  current debug build, but should be revisited with a compatible plugin release.
- iOS compilation and visual launch QA were not run because this host is Windows.
- Android device validation was completed and approved for identity, launch,
  sound preview and delivery, upgrade preservation, and locked-phone Bells.
