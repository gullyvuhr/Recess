# Recess

Recess is an offline-first Flutter app that helps people take an intentional break during the workday. This repository contains the MVP foundation and first complete vertical slice.

## Included in v1

- Onboarding and a locally stored work schedule
- Bells: an immediate local reminder
- Start Recess, Give me a minute, After this, and Rain check actions
- Completion flow and today's progress
- Drift-backed SQLite persistence
- Riverpod state management and GoRouter navigation
- Local notifications; no account or network dependency

Accounts, cloud services, analytics, AI, and sync are intentionally excluded.

## Run

1. Install Flutter and platform tooling.
2. Run `flutter pub get`.
3. Run `flutter run`.

For Android 13+, the app requests notification permission at runtime. Platform projects can be generated with `flutter create . --platforms=android,ios` if they are not present in a checkout.

