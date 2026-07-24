# Recess v1.7.0-beta.3 Release Notes

Build metadata: `1.7.0-beta.3+5`

## Fixed

- Weekly completion now uses the complete active Bell Schedule for the current
  local Monday-Sunday week.
- Future scheduled Bells are included in the expected count.
- Manual and ad hoc Recesses are excluded from scheduled completion.
- Quiet Hours suppress expected occurrences.
- Cadence Schedule now supplies the authoritative occurrence expansion to both
  Bell scheduling and the Insight Engine.

## Unchanged

- Bell cadence, notification identity, lifecycle accounting, persistence
  schema, History, exercise behavior, and offline operation are unchanged.
- Rolling seven-day Fact Engine metrics remain available independently of the
  calendar-week completion observation.

## Verified

- Regression tests cover multiple daily occurrences, future occurrences,
  completed and uncompleted occurrences, Quiet Hours, ad hoc sessions, and
  local week boundaries.
- Dart formatting, Flutter static analysis, and the full Flutter test suite
  pass.
