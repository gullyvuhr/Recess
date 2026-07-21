import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/providers.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/features/history/history_screen.dart';
import 'package:recess/src/features/home/home_screen.dart';

void main() {
  late RecessDatabase database;

  setUp(() => database = RecessDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('shows empty state and disables future navigation',
      (tester) async {
    await _pumpHistory(tester, database);

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Completed movement: 0 min'), findsOneWidget);
    expect(find.text('Not enough Recess history yet.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nothing recorded for these seven days yet.'),
      300,
    );
    expect(find.text('Nothing recorded for these seven days yet.'),
        findsOneWidget);
    expect(find.text('Completed Recesses'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('next-history-period')),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('History is accessible from Home', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          exerciseCatalogProvider.overrideWithValue(const _StaticCatalog()),
          historyNowProvider.overrideWithValue(DateTime(2026, 7, 20, 14)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    expect(find.text('Seven-day summary'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
  });

  testWidgets('navigates to previous period and back to current',
      (tester) async {
    await _pumpHistory(tester, database);
    expect(find.text('Jul 14 – Jul 20'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('previous-history-period')));
    await tester.pumpAndSettle();
    expect(find.text('Jul 7 – Jul 13'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('next-history-period')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('next-history-period')));
    await tester.pumpAndSettle();
    expect(find.text('Jul 14 – Jul 20'), findsOneWidget);
  });

  testWidgets('shows completed row, aggregates, times, and exercise name',
      (tester) async {
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 19, 9),
      createdAt: DateTime(2026, 7, 19, 8),
    );
    await database.startSession(
      session.id,
      DateTime(2026, 7, 19, 9, 5),
      'shoulder-rolls',
    );
    await database.completeSession(session.id, DateTime(2026, 7, 19, 9, 15));

    await _pumpHistory(tester, database);

    await tester.scrollUntilVisible(find.text('Completed'), 400);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.textContaining('Shoulder Rolls'), findsOneWidget);
    expect(find.textContaining('Started 9:05 AM'), findsOneWidget);
    expect(find.textContaining('Completed 9:15 AM'), findsOneWidget);
    expect(find.textContaining('Duration 10m'), findsOneWidget);
    expect(find.textContaining('Response 5m'), findsOneWidget);
    expect(
        find.text('1 completed · 0 deferred · 0 rain checked'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('shows deferred row and deferral count', (tester) async {
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 19, 10),
      createdAt: DateTime(2026, 7, 19, 9),
    );
    await database.deferSession(
      session.id,
      RecessDeferralType.fiveMinutes,
      DateTime(2026, 7, 19, 10, 5),
      DateTime(2026, 7, 19, 10, 1),
    );

    await _pumpHistory(tester, database);

    await tester.scrollUntilVisible(find.text('Deferred'), 400);
    expect(find.text('Deferred'), findsOneWidget);
    expect(find.textContaining('Deferred 1 time'), findsOneWidget);
    expect(
        find.text('0 completed · 1 deferred · 0 rain checked'), findsOneWidget);
  });

  testWidgets('shows rain-check row', (tester) async {
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 19, 11),
      createdAt: DateTime(2026, 7, 19, 10),
    );
    await database.rainCheckSession(session.id, DateTime(2026, 7, 19, 11, 1));

    await _pumpHistory(tester, database);

    await tester.scrollUntilVisible(find.text('Rain checked'), 400);
    expect(find.text('Rain checked'), findsOneWidget);
    expect(
        find.text('0 completed · 0 deferred · 1 rain checked'), findsOneWidget);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester,
  RecessDatabase database,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        exerciseCatalogProvider.overrideWithValue(const _StaticCatalog()),
        historyNowProvider.overrideWithValue(DateTime(2026, 7, 20, 14)),
      ],
      child: const MaterialApp(home: HistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
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
