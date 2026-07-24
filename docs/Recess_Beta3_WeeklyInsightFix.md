# Recess v1.7.0-beta.3: Weekly Insight Correction

## Status

Implemented at `1.7.0-beta.3+5` as a focused behavioral correction. Version
1.6.1 remains the stable baseline. Prior beta and release-candidate records
remain preserved.

## Corrected behavior

- Weekly completion is measured against the active Bell Schedule.
- The reporting window is the current local Monday-Sunday calendar week.
- Every expected occurrence for that week is included, including future Bells.
- Completed scheduled Recesses form the numerator.
- Manual or ad hoc Recesses are excluded from the metric.
- Quiet Hours suppress expected occurrences.
- Deferred, Rain check, completed, or absent session facts do not remove an
  expected occurrence from the denominator.

## Architecture

Cadence Schedule is the single source of truth for expected occurrences.
`RecessSessionService` uses it to plan Bells, and `InsightService` supplies its
week expansion to `InsightEngine`. The Insight Engine no longer reconstructs
schedule expectations from persisted session facts.

The existing rolling seven-day Fact Engine metrics remain unchanged. This
correction applies only to the observation labeled weekly completion.

## Data boundary

No persistence table, schema version, session lifecycle, notification identity,
scheduler cadence, or cloud dependency changed. Scheduled completion is matched
using the immutable original scheduled time. A manual Bell that starts the next
scheduled occurrence early remains part of that occurrence; a separate ad hoc
Recess does not.

## Validation

Regression coverage includes multiple scheduled Recesses per day, future
occurrences later in the week, completed and uncompleted occurrences, Quiet
Hours exclusions, ad hoc completion exclusion, and local Monday-Sunday
boundaries.
