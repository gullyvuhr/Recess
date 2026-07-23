# Changelog

All notable Recess changes are recorded here.

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
