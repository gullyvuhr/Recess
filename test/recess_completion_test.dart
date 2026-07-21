import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/providers.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/features/recess/recess_screen.dart';

void main() {
  testWidgets('completion stays centered for the existing two-second display',
      (tester) async {
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final database = RecessDatabase(NativeDatabase.memory());
    final notifications = _FakeNotifications();
    var now = DateTime(2026, 7, 20, 10);
    await database.saveSchedule(
      const WorkSchedule(
        startMinutes: 9 * 60,
        endMinutes: 17 * 60,
        cadenceMinutes: 60,
      ),
    );
    final scheduled = await database.createSession(
      scheduledAt: now,
      createdAt: now.subtract(const Duration(minutes: 10)),
    );
    await database.startSession(scheduled.id, now, 'shoulder-rolls');
    final router = GoRouter(
      initialLocation: '/recess/${scheduled.id}',
      routes: [
        GoRoute(
          path: '/recess/:sessionId',
          builder: (_, state) => RecessScreen(
            sessionId: int.parse(state.pathParameters['sessionId']!),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home refreshed')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          notificationServiceProvider.overrideWithValue(notifications),
          exerciseCatalogProvider.overrideWithValue(const _StaticCatalog()),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp.router(
          theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xff315c4b)),
            scaffoldBackgroundColor: const Color(0xfff7f3e8),
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    now = now.add(const Duration(minutes: 5));
    await tester.tap(find.text("I'm back"));
    for (var attempt = 0;
        attempt < 20 &&
            find.byKey(const Key('completion-primary')).evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    final primary = tester.widget<Text>(
      find.byKey(const Key('completion-primary')),
    );
    final supporting = tester.widget<Text>(
      find.byKey(const Key('completion-supporting')),
    );
    expect(primary.textAlign, TextAlign.center);
    expect(supporting.textAlign, TextAlign.center);
    final liveRegion = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const Key('completion-primary')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(liveRegion.properties.liveRegion, isTrue);
    expect(
      platformCalls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.lightImpact',
            ),
      ),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.check_circle_outline)).dx,
      tester.getCenter(find.byType(Scaffold)).dx,
    );

    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byKey(const Key('completion-primary')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Home refreshed'), findsOneWidget);

    router.dispose();
    await notifications.close();
    await database.close();
  });
}

class _FakeNotifications implements BellNotifications {
  final _opened = StreamController<String>.broadcast();
  final _pending = <PendingCadenceBell>[];

  Future<void> close() => _opened.close();

  @override
  Stream<String> get openedPayloads => _opened.stream;

  @override
  Future<void> cancelCadenceBell({Set<int> retaining = const {}}) async {
    _pending.removeWhere((bell) => !retaining.contains(bell.id));
  }

  @override
  Future<void> cancelDeferredBell() async {}

  @override
  Future<List<PendingCadenceBell>> pendingCadenceBells() async => _pending;

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
    _pending.removeWhere((bell) => bell.id == id);
    _pending.add(PendingCadenceBell(id: id, scheduledAt: scheduledAt));
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
          description: 'Roll your shoulders slowly.',
          category: ExerciseCategory.mobility,
          difficulty: ExerciseDifficulty.standard,
          estimatedDuration: 3,
        ),
      ];
}
