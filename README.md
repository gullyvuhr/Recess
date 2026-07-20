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

## Why is the source public?

Recess is being built in the open because good products get better when people can see how they're made. You're welcome to explore the code, learn from it, contribute, and use it for personal or internal purposes. What you can't do is turn it into a competing commercial product while Recess is actively being developed. The complete terms are described in the LICENSE file.

## Run

1. Install Flutter and platform tooling.
2. Run `flutter pub get`.
3. Run `flutter run`.

For Android 13+, the app requests notification permission at runtime. Platform projects can be generated with `flutter create . --platforms=android,ios` if they are not present in a checkout.
