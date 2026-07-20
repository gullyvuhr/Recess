import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/providers.dart';
import 'package:recess/src/features/onboarding/onboarding_screen.dart';

void main() {
  late RecessDatabase database;
  late FakeNotifications notifications;

  setUp(() {
    database = RecessDatabase(NativeDatabase.memory());
    notifications = FakeNotifications();
  });

  tearDown(() async {
    await notifications.close();
    await database.close();
  });

  testWidgets('new schedules default to a 60-minute Bell cadence',
      (tester) async {
    await _pumpScheduleScreen(tester, database, notifications);

    expect(find.text('How often should Bells ring?'), findsOneWidget);
    expect(find.text('Every 60 minutes'), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
  });

  testWidgets('editing loads the complete persisted work schedule',
      (tester) async {
    await database.saveSchedule(
      const WorkSchedule(
        startMinutes: 8 * 60 + 30,
        endMinutes: 16 * 60 + 15,
        cadenceMinutes: 90,
      ),
    );

    await _pumpScheduleScreen(
      tester,
      database,
      notifications,
      editing: true,
    );

    expect(find.text('Every 90 minutes'), findsOneWidget);
    expect(find.text('8:30 AM'), findsOneWidget);
    expect(find.text('4:15 PM'), findsOneWidget);
  });

  testWidgets('saving cadence preserves times and rebuilds notifications',
      (tester) async {
    await database.saveSchedule(
      const WorkSchedule(
        startMinutes: 8 * 60 + 30,
        endMinutes: 16 * 60 + 15,
        cadenceMinutes: 60,
      ),
    );
    await _pumpScheduleScreen(
      tester,
      database,
      notifications,
      editing: true,
    );

    await tester.tap(find.byKey(const ValueKey('bell-cadence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 45 minutes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    final saved = await database.schedule();
    expect(saved!.startMinutes, 8 * 60 + 30);
    expect(saved.endMinutes, 16 * 60 + 15);
    expect(saved.cadenceMinutes, 45);
    expect(notifications.cadenceCancellationCount, 1);
    expect(notifications.cadence, isNotEmpty);
    expect(find.text('Home'), findsOneWidget);
  });
}

Future<void> _pumpScheduleScreen(
  WidgetTester tester,
  RecessDatabase database,
  FakeNotifications notifications, {
  bool editing = false,
}) async {
  final router = GoRouter(
    initialLocation: editing ? '/onboarding?edit=true' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, state) => OnboardingScreen(
          editing: state.uri.queryParameters['edit'] == 'true',
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class FakeNotifications implements BellNotifications {
  final cadence = <DateTime>[];
  final _opened = StreamController<String>.broadcast();
  var cadenceCancellationCount = 0;

  @override
  Stream<String> get openedPayloads => _opened.stream;

  Future<void> close() => _opened.close();

  @override
  Future<void> cancelCadenceBell() async {
    cadenceCancellationCount++;
    cadence.clear();
  }

  @override
  Future<void> cancelDeferredBell() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> ringBells(int sessionId, {required bool deferred}) async => true;

  @override
  Future<bool> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt,
  ) async {
    cadence.add(scheduledAt);
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
