import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/providers.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/features/home/home_screen.dart';

void main() {
  late RecessDatabase database;
  late _FakeNotifications notifications;
  late DateTime now;
  late ProviderContainer container;

  setUp(() {
    database = RecessDatabase(NativeDatabase.memory());
    notifications = _FakeNotifications();
    now = DateTime(2026, 7, 20, 9, 30);
  });

  tearDown(() async {
    container.dispose();
    await notifications.close();
    await database.close();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(notifications),
        exerciseCatalogProvider.overrideWithValue(const _StaticCatalog()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> saveSchedule() => database.saveSchedule(
        const WorkSchedule(
          startMinutes: 9 * 60,
          endMinutes: 17 * 60,
          cadenceMinutes: 60,
        ),
      );

  testWidgets('shows the persisted scheduled next Recess', (tester) async {
    await saveSchedule();
    await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 12),
      createdAt: now,
    );

    await pumpHome(tester);

    expect(find.text('Your workday is 9:00 AM–5:00 PM.'), findsOneWidget);
    expect(find.text('Next Recess: 12:00 PM'), findsOneWidget);
    expect(find.text('Bells'), findsOneWidget);
    expect(find.text("Today's progress"), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Deferred'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(
      find.text(
        'More insights will appear as Recess remembers your activity.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Average response'), findsNothing);
    expect(find.textContaining('Average duration'), findsNothing);
    expect(find.textContaining('Completed movement'), findsNothing);
  });

  testWidgets('shows the persisted deferred time', (tester) async {
    await saveSchedule();
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 11),
      createdAt: now,
    );
    await database.deferSession(
      session.id,
      RecessDeferralType.afterThis,
      DateTime(2026, 7, 20, 12),
      DateTime(2026, 7, 20, 11, 45),
    );

    await pumpHome(tester);

    expect(find.text('Next Recess: 12:00 PM'), findsOneWidget);
  });

  testWidgets('shows an active Recess', (tester) async {
    await saveSchedule();
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 10),
      createdAt: now,
    );
    await database.startSession(
      session.id,
      DateTime(2026, 7, 20, 10),
      'shoulder-rolls',
    );

    await pumpHome(tester);

    expect(find.text('Recess in progress'), findsOneWidget);
    expect(find.text('Resume Recess'), findsOneWidget);
  });

  testWidgets('shows no remaining Recess today', (tester) async {
    await saveSchedule();

    await pumpHome(tester);

    expect(find.text('No more Recesses scheduled today'), findsOneWidget);
  });

  testWidgets('preserves onboarding state without a schedule', (tester) async {
    await pumpHome(tester);

    expect(find.text('Set a work schedule'), findsOneWidget);
    expect(find.textContaining('Next Recess:'), findsNothing);
    expect(
      find.text('More insights will appear as Recess remembers your activity.'),
      findsOneWidget,
    );
  });

  testWidgets('refreshes after completion', (tester) async {
    await saveSchedule();
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 10),
      createdAt: now,
    );
    await database.startSession(
      session.id,
      DateTime(2026, 7, 20, 10),
      'shoulder-rolls',
    );
    await pumpHome(tester);
    expect(find.text('Recess in progress'), findsOneWidget);

    now = DateTime(2026, 7, 20, 10, 6);
    await container.read(recessActionsProvider).complete(session.id);
    await tester.pumpAndSettle();

    expect(find.text('Next Recess: 11:00 AM'), findsOneWidget);
    expect(find.textContaining('Average duration'), findsNothing);
  });

  testWidgets('shows only the highest-ranked observation', (tester) async {
    await saveSchedule();
    for (var day = 17; day <= 20; day++) {
      final scheduled = DateTime(2026, 7, day, 10);
      final session = await database.createSession(
        scheduledAt: scheduled,
        createdAt: scheduled.subtract(const Duration(minutes: 5)),
      );
      await database.startSession(
        session.id,
        scheduled.add(const Duration(minutes: 2)),
        'shoulder-rolls',
      );
      await database.completeSession(
        session.id,
        scheduled.add(const Duration(minutes: 7)),
      );
    }

    await pumpHome(tester);

    expect(
      find.text('You completed 4 of 4 scheduled Recesses this week.'),
      findsOneWidget,
    );
    expect(find.text('Seven-day completion'), findsNothing);
    expect(find.textContaining('Average response'), findsNothing);
  });

  testWidgets('refreshes after deferral', (tester) async {
    await saveSchedule();
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 10),
      createdAt: now,
    );
    now = DateTime(2026, 7, 20, 10);
    await pumpHome(tester);
    expect(find.text('Next Recess: 10:00 AM'), findsOneWidget);

    await container
        .read(recessActionsProvider)
        .defer(session.id, RecessDeferralType.fiveMinutes);
    await tester.pumpAndSettle();

    expect(find.text('Next Recess: 10:05 AM'), findsOneWidget);
  });

  testWidgets('refreshes after rain check', (tester) async {
    await saveSchedule();
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 10),
      createdAt: now,
    );
    now = DateTime(2026, 7, 20, 10);
    await pumpHome(tester);

    await container.read(recessActionsProvider).rainCheck(session.id);
    await tester.pumpAndSettle();

    expect(find.text('Next Recess: 11:00 AM'), findsOneWidget);
  });

  testWidgets('refreshes after app restore', (tester) async {
    await saveSchedule();
    await pumpHome(tester);
    expect(find.text('No more Recesses scheduled today'), findsOneWidget);

    await container.read(recessActionsProvider).restore();
    await tester.pumpAndSettle();

    expect(find.text('Next Recess: 10:00 AM'), findsOneWidget);
  });

  testWidgets('refreshes after schedule save', (tester) async {
    await pumpHome(tester);
    expect(find.text('Set a work schedule'), findsOneWidget);

    await container.read(recessActionsProvider).saveSchedule(
          const WorkSchedule(
            startMinutes: 9 * 60,
            endMinutes: 17 * 60,
            cadenceMinutes: 60,
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Your workday is 9:00 AM–5:00 PM.'), findsOneWidget);
    expect(find.text('Next Recess: 10:00 AM'), findsOneWidget);
  });
}

class _FakeNotifications implements BellNotifications {
  final _opened = StreamController<String>.broadcast();
  final _cadence = <int, PendingCadenceBell>{};

  Future<void> close() => _opened.close();

  @override
  Stream<String> get openedPayloads => _opened.stream;
  @override
  Future<void> cancelCadenceBell({Set<int> retaining = const {}}) async {
    _cadence.removeWhere((id, _) => !retaining.contains(id));
  }

  @override
  Future<void> cancelDeferredBell() async {}
  @override
  Future<List<PendingCadenceBell>> pendingCadenceBells() async =>
      _cadence.values.toList(growable: false);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> ringBells(int sessionId, {required bool deferred}) async => true;
  @override
  Future<bool> scheduleCadenceBell(int sessionId, DateTime scheduledAt) async {
    final id = NotificationService.cadenceNotificationId(scheduledAt);
    _cadence[id] = PendingCadenceBell(id: id, scheduledAt: scheduledAt);
    return true;
  }

  @override
  Future<bool> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt,
  ) async =>
      true;
  @override
  String? takeInitialPayload() => null;
}

class _StaticCatalog implements ExerciseCatalog {
  const _StaticCatalog();

  @override
  Future<List<Exercise>> load() async => const [
        Exercise(
          id: 'shoulder-rolls',
          title: 'Shoulder Rolls',
          instruction: 'Roll your shoulders.',
          durationMinutes: 2,
          category: ExerciseCategory.movement,
          availableIndoors: true,
          availableOutdoors: true,
        ),
      ];
}
