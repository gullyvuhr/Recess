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
  local previews and selected-sound delivery for manual and scheduled Bells;
  all three are reproducible original procedural assets
- Original cream-and-green Recess bell identity across Android legacy, round,
  adaptive, monochrome, native splash, and the complete iOS icon catalog
- Sprint 5.1 Product Polish with clearer copy, large-text-safe Settings,
  improved semantics, standard Workday navigation, and restrained native
  haptics
- Production-polish beta at `1.7.0-beta.2+3`, with refined native
  identity, cream launch surfaces, local release-signing configuration, upgrade
  preservation coverage, resume-time Bell reconciliation, and an explicit
  release-readiness checklist
- Riverpod state management and GoRouter navigation

Accounts, cloud services, analytics, AI, and sync are intentionally excluded.

## Product backlog

- "Need a Recess Now" must create an unscheduled, ad hoc Recess without
  consuming, advancing, or completing the next scheduled Bell. The existing
  manual Bell action continues to trigger the next scheduled Recess early.

## Documentation

The canonical documentation set is indexed in [Recess_Master_Documentation_Index_v1.7.0-beta.2.docx](docs/Recess_Master_Documentation_Index_v1.7.0-beta.2.docx). Version 1.7.0-beta.2 is the current Beta candidate and records the production-polish pass. Version 1.6.1 remains the current Stable; beta.1 and lower versions remain historical. Detailed implementation records are available for [Sprint 4](docs/Recess_Sprint4_ExerciseEngine.md), [Sprint 5.1](docs/Recess_Sprint5.1_ProductPolish.md), [Sprint 5.2](docs/Recess_Sprint5.2_BetaRelease.md), and [beta.2 production polish](docs/Recess_Beta2_ProductionPolish.md).

## Why is the source public?

Recess is being built in the open because good products get better when people can see how they're made. You're welcome to explore the code, learn from it, contribute, and use it for personal or internal purposes. What you can't do is turn it into a competing commercial product while Recess is actively being developed. The complete terms are described in the LICENSE file.

Recess uses the Business Source License 1.1 and changes to Apache License 2.0 on January 1, 2030.

## Run

1. Install Flutter and platform tooling.
2. Run `flutter pub get`.
3. Run `flutter run`.

For Android 12+, the app requests exact-alarm access so scheduled Bells can be
delivered while the device is idle. Android 13+ also requires notification
permission. Platform projects can be generated with
`flutter create . --platforms=android,ios` if they are not present in a checkout.

Beta installation, signing, upgrade, asset, and release-blocker instructions are
recorded in [the Sprint 5.2 release checklist](docs/Recess_Beta_Release_Checklist_v1.7.0-beta.1.md).
Visual and audio provenance is tracked in the
[current beta release asset manifest](docs/Recess_Release_Asset_Manifest_v1.7.0-beta.2.md).
Changes in this candidate are summarized in the
[v1.7.0-beta.2 release notes](docs/Recess_Release_Notes_v1.7.0-beta.2.md).
