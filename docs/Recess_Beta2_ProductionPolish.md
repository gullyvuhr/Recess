# Recess v1.7.0-beta.2: Production Polish

## Status

Implemented as the next beta candidate at `1.7.0-beta.2+3`. This is a focused
quality pass over the existing offline product, not a new capability release.
Version 1.6.1 remains the current Stable and v1.7.0-beta.1 remains historical.

## Identity refinement

- Redrew the original Recess bell using a distinct rounded cap, smoother dome,
  balanced shoulder and flare, slimmer rim, and smaller clapper.
- Preserved the established green `#315C4B`, cream `#F7F3E8`, bell metaphor,
  deterministic generator, and rounded-square launcher structure.
- Regenerated Android legacy, round, adaptive foreground, Android 13
  monochrome, and native splash resources. Shared iOS icon and launch assets
  were regenerated from the same canonical geometry to prevent identity drift.
- Verified the 432 px adaptive foreground alpha bounds at `(119, 87)` through
  `(313, 343)` and reviewed circular, rounded-square, squircle, and square masks.

## Product polish and accessibility

- Added a system-aware dark theme derived from the existing Recess green while
  preserving the cream light theme and Material 3 component behavior.
- Retained established responsive scrolling, large-text reflow, semantic labels,
  tooltips, platform-default focus order, and Material touch targets.
- Changed the Android notification small icon from the full-color launcher
  bitmap to the existing monochrome bell drawable, which satisfies the native
  status-icon contract without changing notification behavior.

## Notifications and hardening

- Replaced tentative notification copy with the concise title `Time for Recess`
  and body `Take a few minutes to move and reset.` for scheduled, deferred, and
  manual Bells.
- Refreshes the local timezone and reconciles the existing Bell schedule when
  the app resumes. Startup restore, exact alarms, boot restoration, notification
  identities, payload actions, cadence, and session accounting remain intact.
- Removed temporary cadence and pending-ID debug logging. No product facts,
  persistence, schema, Insight calculations, or exercise behavior changed.

## Validation scope

Coverage includes icon configuration, notification copy and exact-alarm mode,
manual/scheduled/deferred actions, restore and cancellation, upgrade
persistence, scheduler cadence, History, Fact Engine, Insight Engine, Home,
Settings, and the complete existing unit/widget suite. Android bundle and APK
packaging validate the regenerated resources.

## Deliberately deferred

- No calendar, account, authentication, cloud, sync, telemetry, remote API, AI,
  new exercise, new screen, or scheduling intelligence was introduced.
- Release APK/AAB assembly remains subject to the existing local Java/Maven
  trust-store limitation. iOS build and native visual QA require macOS/Xcode.
- The inactive Flutter-template `LaunchImage.imageset` remains unreferenced; it
  is not part of the active iOS launch screen.

## Release-candidate stabilization audit

### Safe changes made

- Resume-time timezone lookup now preserves the last successfully resolved
  timezone when the platform lookup fails transiently. UTC remains only the
  initial fallback when no timezone has ever been resolved.
- Resume reconciliation contains transient notification/database failures so a
  later startup or resume can retry without an unhandled asynchronous error.
- Removed the private notification `repeatsDaily` parameter and conditional
  path because every caller schedules one-shot Bells. Notification identity,
  timing, exact-alarm mode, payloads, and actions are unchanged.
- Removed the unused direct `cupertino_icons` dependency and refreshed the
  lockfile. No replacement dependency was added.

### Issues found

- Quiet Hours now filters scheduled cadence and deferred Bells through one
  local wall-clock rule. Bells inside same-day or overnight ranges are skipped,
  not delayed, and the original cadence remains unchanged. Settings changes,
  resume, reconciliation, schedule edits, and notification rebuilding all use
  the same rule.
- The Fact Engine intentionally has no missed or expired status. An ignored
  notification is not treated as proof of a missed Recess; Rain check is the
  supported explicit dismiss outcome. No missed handling was invented here.
- The inactive iOS `LaunchImage.imageset` is unreferenced by the active launch
  storyboard. It was left in the asset catalog because native iOS build
  validation is unavailable on this Windows host.
- No stale TODO, FIXME, HACK, production debug log, or debug-only UI remains in
  `lib/`. Other declared runtime dependencies are directly used.

### Automated validation

- `flutter pub get`: passed; removed `cupertino_icons` from the dependency graph.
- `dart format --output=none --set-exit-if-changed lib test`: passed, 42 files
  unchanged.
- `flutter analyze`: passed with no issues.
- Focused Quiet Hours cadence, reconciliation, deferred reminder, Settings, and
  existing session tests: passed, 43 tests.
- Full `flutter test --concurrency=1`: passed, 136 tests.
- `flutter build bundle`: passed.
- `flutter build apk --debug`: passed.
- `git diff --check`: passed.

### Remaining manual device checks

- Upgrade over the current beta without clearing data; confirm schedule,
  preferences, History, and Insights persist.
- Exercise first-run notification denial, later enablement, and exact-alarm
  access; confirm the app remains usable when permission is denied.
- Create and edit a workday, then verify the next-Recess display and rebuilt
  pending Bell cadence.
- Validate both a same-day Quiet Hours range and an overnight range on a locked
  device, including one Bell immediately before and after the range.
- Validate scheduled Bell, Give me a minute, After this, Rain check, Start,
  completion, and repeated notification-tap behavior.
- Force-stop/reopen, reboot, and change device timezone across a DST-observing
  zone; confirm future Bells reconcile without duplicate or stale alarms.

### RC readiness

The checked-in implementation now matches the Quiet Hours product language.
Automated coverage cleared the source-level blocker. Subsequent physical Android
validation passed for same-day and overnight Quiet Hours, locked-phone delivery,
resume, reboot, reconciliation, deferred Bells, schedule edits, and manual
Bells. The scheduler cadence, lifecycle, persistence schema, History, Fact
Engine, and Insight Engine remain unchanged. These results support promotion to
`v1.0.0-rc.1`.
