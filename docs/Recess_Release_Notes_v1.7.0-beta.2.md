# Recess v1.7.0-beta.2 Release Notes

Build metadata: `1.7.0-beta.2+3`

## Changed

- Refined the original Recess bell for clearer small-size recognition and more
  balanced launcher-mask placement.
- Added a native system-aware dark theme while preserving the cream light theme.
- Tightened Bell notification copy to be concise, calm, and intentional.
- Uses the monochrome bell as the Android notification status icon.

## Fixed

- Reconciles timezone context and pending Bells when the app resumes after a
  device timezone or daylight-saving transition.
- Removed temporary cadence diagnostic logging from production paths.

## Verified

- Android legacy, round, adaptive, monochrome, and native splash resources.
- Circular, rounded-square, squircle, and square adaptive-icon masks.
- Exact-alarm scheduling, locked/background Bell contracts, notification taps,
  defer, Rain check, Start, completion, cancellation, and schedule restoration.
- Upgrade, settings, History, Fact Engine, Insight Engine, Home, and offline
  persistence behavior.
- Formatting, static analysis, full unit/widget suite, Flutter bundle, Android
  debug APK, and Git whitespace validation.

## Known limitations

- Release APK/AAB assembly can be blocked on the current Windows host by the
  existing Java/Maven PKIX trust-store issue; this is not an application error.
- iOS compilation and native visual validation require macOS/Xcode.
- `flutter_timezone` emits a non-blocking future Kotlin-plugin compatibility
  warning during Android builds.
