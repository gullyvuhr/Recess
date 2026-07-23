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
