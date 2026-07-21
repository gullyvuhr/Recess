# Recess

Recess is an offline-first Flutter app that helps people take an intentional break during the workday. Its local Bell, session, Fact Engine, and History capabilities work without an account, server, network, or cloud service.

## Current capabilities

- Configurable local workday and Bell cadence
- Rolling seven-day, work-start-anchored local Bell scheduling
- Stable one-shot notification IDs with separate deferred reminders
- Manual Bell retained as an immediate test function
- Start Recess, Give me a minute, After this, Rain check, and manual completion
- Drift-backed Fact Engine preserving scheduling, response, deferral, exercise, and completion facts
- History v1 with seven-day summaries and expandable day-level detail
- Insight Engine v1 with deterministic Today and rolling seven-day metrics, plus up to three evidence-supported observations
- Home Dashboard v2 with a full-screen, live next-Recess hero above compact
  local daily progress and one ranked Insight Engine observation
- Centered completion transition with curated, context-aware encouragement that
  returns to the refreshed Home dashboard
- Sprint 3 Settings with local workday access, Recess duration, exercise
  difficulty, Bell sound, quiet hours, notification preference, and About
- Sprint 4 Exercise Engine with a 30-exercise offline library, structured
  metadata, difficulty-aware deterministic selection, recent-exercise
  avoidance, and duration-aware timed, repetition, hold, and sequence
  prescriptions
- Bundled School Bell, Coach Whistle, and Gentle Chime sounds with immediate
  local previews and selected-sound delivery for manual and scheduled Bells
- Riverpod state management and GoRouter navigation

Accounts, cloud services, analytics, AI, and sync are intentionally excluded.

## Product backlog

- "Need a Recess Now" must create an unscheduled, ad hoc Recess without
  consuming, advancing, or completing the next scheduled Bell. The existing
  manual Bell action continues to trigger the next scheduled Recess early.

## Documentation

The canonical released documentation set is indexed in [Recess_Master_Documentation_Index_v1.6.0.docx](docs/Recess_Master_Documentation_Index_v1.6.0.docx). Version 1.6.0 records Sprint 4 Exercise Engine, prescriptions, Bell Sounds, and the completion experience as complete. Version 1.5.0 and lower versions remain historical. The detailed implementation record is [Recess_Sprint4_ExerciseEngine.md](docs/Recess_Sprint4_ExerciseEngine.md).

## Why is the source public?

Recess is being built in the open because good products get better when people can see how they're made. You're welcome to explore the code, learn from it, contribute, and use it for personal or internal purposes. What you can't do is turn it into a competing commercial product while Recess is actively being developed. The complete terms are described in the LICENSE file.

Recess uses the Business Source License 1.1 and changes to Apache License 2.0 on January 1, 2030.

## Run

1. Install Flutter and platform tooling.
2. Run `flutter pub get`.
3. Run `flutter run`.

For Android 13+, the app requests notification permission at runtime. Platform projects can be generated with `flutter create . --platforms=android,ios` if they are not present in a checkout.
