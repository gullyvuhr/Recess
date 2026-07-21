# Recess Sprint 3: Settings

Status: Complete in version 1.5.0 (2026-07-21)

Sprint 3 adds a complete offline Settings screen using the existing local
`settings` table and Riverpod architecture.

## Implemented

- Existing workday and Bell cadence editor access
- Recess duration preference: 3, 5, 10, or 15 minutes
- Exercise difficulty preference: Easy, Standard, or Challenging
- Bell sound preference: School Bell, Coach Whistle, or Gentle Chime
- Quiet hours preference with enabled state, start time, and end time
- Notification preference with the existing permission request when enabled
- Local About information for Recess version 0.1.0 build 1

All preferences remain on the device. Sprint 3 does not change scheduling,
exercise selection, notification delivery, session accounting, or history.
Duration, difficulty, Bell sound, quiet hours, and notification preference are
stored for their future runtime integrations.
