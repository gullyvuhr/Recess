# Changelog

All notable Recess changes are recorded here.

## 1.7.0-beta.3 - 2026-07-24

### Fixed

- Weekly completion now measures scheduled completions against every expected
  occurrence in the active Bell Schedule for the current local Monday-Sunday
  week.
- Future scheduled Bells remain in the denominator, while manual or ad hoc
  Recesses are excluded.
- Quiet Hours suppress expected occurrences without changing cadence.
- Bell scheduling and weekly Insight derivation now share Cadence Schedule as
  the authoritative expected-occurrence calculation.

### Verification

- Formatting, static analysis, and the complete automated test suite pass.
- Regression coverage includes multiple daily Bells, future weekly
  occurrences, completed and uncompleted occurrences, Quiet Hours, ad hoc
  sessions, and local week boundaries.

## 1.0.0-rc.1 - 2026-07-23

### Added

- Complete offline-first workday scheduling, local notification, session,
  History, Fact Engine, Insight Engine, Settings, and Exercise Engine flows.
- Original Recess identity, native launch treatment, and bundled Bell sounds.
- Exact Android alarm support for locked-phone and background Bell delivery.

### Changed

- Quiet Hours now skips scheduled and deferred Bells inside same-day or
  overnight ranges without shifting the normal cadence.
- Resume, schedule editing, and notification reconciliation apply the same
  persisted Quiet Hours rule.
- Production copy, accessibility, large-text behavior, completion presentation,
  dark mode, and native identity were polished for release-candidate use.

### Fixed

- Pending Bells reconcile after resume, reboot, schedule changes, timezone
  changes, and daylight-saving transitions.
- Notification timezone lookup preserves its last valid local timezone after a
  transient platform lookup failure.

### Verification

- Android scheduling, locked-phone delivery, Quiet Hours, deferred Bells,
  reboot recovery, schedule editing, and manual Bells passed physical-device
  validation.
- Flutter static analysis and the complete automated test suite pass.
- Release-mode APK and App Bundle assembly pass. Distribution signing remains
  external because no release keystore is stored in this checkout.
