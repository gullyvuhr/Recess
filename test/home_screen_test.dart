import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/insights.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/providers.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/features/home/home_screen.dart';

void main() {
  late RecessDatabase database;
  late _FakeNotifications notifications;
  late DateTime now;
  ProviderContainer? container;

  setUp(() {
    database = RecessDatabase(NativeDatabase.memory());
    notifications = _FakeNotifications();
    now = DateTime(2026, 7, 20, 9, 30);
  });

  tearDown(() async {
    container?.dispose();
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
        container: container!,
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

  test('formats human-readable countdown boundaries', () {
    final base = DateTime(2026, 7, 20, 9);
    expect(formatRecessCountdown(base, base), 'Ready when you are');
    expect(formatRecessCountdown(base.add(const Duration(seconds: 45)), base),
        'In less than a minute');
    expect(formatRecessCountdown(base.add(const Duration(minutes: 1)), base),
        'In 1 minute');
    expect(
      formatRecessCountdown(
          base.add(const Duration(hours: 2, minutes: 30)), base),
      'In 2 hr 30 min',
    );
  });

  test('formats Today facts with correct singular and plural copy', () {
    expect(
      formatTodayProgress(
        const TodayInsightMetrics(
          completed: 0,
          deferred: 0,
          missed: null,
          completedMovementDuration: Duration.zero,
        ),
      ),
      '0 recesses · 0 movement minutes',
    );
    expect(
      formatTodayProgress(
        const TodayInsightMetrics(
          completed: 1,
          deferred: 0,
          missed: null,
          completedMovementDuration: Duration(minutes: 1),
        ),
      ),
      '1 recess · 1 movement minute',
    );
  });

  testWidgets('shows the persisted scheduled next Recess', (tester) async {
    await saveSchedule();
    await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 12),
      createdAt: now,
    );

    await pumpHome(tester);

    expect(find.text('NEXT RECESS'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(find.text('Your next Recess is in'), findsOneWidget);
    expect(find.text('2 hr 30 min'), findsOneWidget);
    expect(find.text('Start Now'), findsOneWidget);
    expect(find.text('Bells'), findsOneWidget);
    expect(find.byTooltip('History'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.history),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.settings_outlined),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.byType(Card), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('0 recesses · 0 movement minutes'), findsOneWidget);
    expect(find.text('Insight'), findsOneWidget);
    expect(
      find.text(
        'A useful observation will appear as your Recess history grows.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Average response'), findsNothing);
    expect(find.textContaining('Average duration'), findsNothing);
    expect(find.textContaining('Completed movement'), findsNothing);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('View all'), findsNothing);
  });

  testWidgets('standard phone viewport does not require scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await saveSchedule();
    await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 12),
      createdAt: now,
    );

    await pumpHome(tester);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, 0);
    expect(find.text('Insight'), findsOneWidget);
  });

  testWidgets('labeled Bells control preserves the manual bell action',
      (tester) async {
    await saveSchedule();
    await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 12),
      createdAt: now,
    );
    await pumpHome(tester);

    await tester.tap(find.text('Bells'));
    await tester.pumpAndSettle();

    expect(find.text('The Bells rang.'), findsOneWidget);
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

    expect(find.text('12:00'), findsOneWidget);
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

    expect(find.text('All done for today'), findsOneWidget);
  });

  testWidgets('preserves onboarding state without a schedule', (tester) async {
    await pumpHome(tester);

    expect(find.text('Set your workday'), findsOneWidget);
    expect(find.textContaining('Next Recess:'), findsNothing);
    expect(
      find.text(
          'A useful observation will appear as your Recess history grows.'),
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
    await container!.read(recessActionsProvider).complete(session.id);
    await tester.pumpAndSettle();

    expect(find.text('11:00'), findsOneWidget);
    expect(find.textContaining('Average duration'), findsNothing);
  });

  testWidgets('shows only the highest-ranked observation', (tester) async {
    await saveSchedule();
    now = DateTime(2026, 7, 20, 14);
    for (var hour = 10; hour <= 13; hour++) {
      final scheduled = DateTime(2026, 7, 20, hour);
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
      find.text('You completed 4 of 49 scheduled Recesses this week.'),
      findsOneWidget,
    );
    expect(find.text('Seven-day completion'), findsNothing);
    expect(find.textContaining('Average response'), findsNothing);
  });

  testWidgets('shows compact today facts without recent activity',
      (tester) async {
    await saveSchedule();
    final scheduled = DateTime(2026, 7, 20, 9);
    final session = await database.createSession(
      scheduledAt: scheduled,
      createdAt: scheduled,
    );
    await database.startSession(session.id, scheduled, 'shoulder-rolls');
    await database.completeSession(
      session.id,
      scheduled.add(const Duration(minutes: 2)),
    );

    await pumpHome(tester);

    expect(find.text('1 recess · 2 movement minutes'), findsOneWidget);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('Shoulder Rolls'), findsNothing);
  });

  testWidgets('refreshes after deferral', (tester) async {
    await saveSchedule();
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 10),
      createdAt: now,
    );
    now = DateTime(2026, 7, 20, 10);
    await pumpHome(tester);
    expect(find.text('10:00'), findsOneWidget);

    await container!
        .read(recessActionsProvider)
        .defer(session.id, RecessDeferralType.fiveMinutes);
    await tester.pumpAndSettle();

    expect(find.text('10:05'), findsOneWidget);
  });

  testWidgets('refreshes after rain check', (tester) async {
    await saveSchedule();
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 10),
      createdAt: now,
    );
    now = DateTime(2026, 7, 20, 10);
    await pumpHome(tester);

    await container!.read(recessActionsProvider).rainCheck(session.id);
    await tester.pumpAndSettle();

    expect(find.text('11:00'), findsOneWidget);
  });

  testWidgets('refreshes after app restore', (tester) async {
    await saveSchedule();
    await pumpHome(tester);
    expect(find.text('All done for today'), findsOneWidget);

    await container!.read(recessActionsProvider).restore();
    await tester.pumpAndSettle();

    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('refreshes after schedule save', (tester) async {
    await pumpHome(tester);
    expect(find.text('Set your workday'), findsOneWidget);

    await container!.read(recessActionsProvider).saveSchedule(
          const WorkSchedule(
            startMinutes: 9 * 60,
            endMinutes: 17 * 60,
            cadenceMinutes: 60,
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('10:00'), findsOneWidget);
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
  Future<bool> ringBells(
    int sessionId, {
    required bool deferred,
    BellSound sound = BellSound.schoolBell,
  }) async =>
      true;
  @override
  Future<bool> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async {
    final id = NotificationService.cadenceNotificationId(scheduledAt);
    _cadence[id] = PendingCadenceBell(id: id, scheduledAt: scheduledAt);
    return true;
  }

  @override
  Future<bool> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async =>
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
