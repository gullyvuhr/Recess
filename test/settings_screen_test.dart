import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/providers.dart';
import 'package:recess/src/core/bell_audio.dart';
import 'package:recess/src/features/settings/settings_screen.dart';

void main() {
  late RecessDatabase database;
  late _FakeNotifications notifications;
  late _FakePreviewPlayer previewPlayer;

  setUp(() {
    database = RecessDatabase(NativeDatabase.memory());
    notifications = _FakeNotifications();
    previewPlayer = _FakePreviewPlayer();
  });

  tearDown(() async {
    await notifications.close();
    await database.close();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          notificationServiceProvider.overrideWithValue(notifications),
          bellPreviewPlayerProvider.overrideWithValue(previewPlayer),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select<T>(
    WidgetTester tester,
    Key key,
    String label,
  ) async {
    final dropdown = find.descendant(
      of: find.byKey(key),
      matching: find.byType(DropdownButton<T>),
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows complete settings groups and defaults', (tester) async {
    await database.saveSchedule(
      const WorkSchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
    );
    await pumpSettings(tester);

    expect(find.text('Workday'), findsOneWidget);
    expect(find.text('9:00 AM to 5:00 PM · Bells every 60 minutes'),
        findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('School Bell'), findsOneWidget);
    expect(find.text('Notifications on'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Offline First'), 300);
    expect(find.text('Version 0.1.0 (1) · Offline First'), findsOneWidget);
    expect(find.textContaining('Recess is a quiet reminder'), findsOneWidget);
    expect(find.textContaining('does not collect or send personal data'),
        findsOneWidget);
  });

  testWidgets('updates duration, difficulty, and bell selection',
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
    await pumpSettings(tester);

    await select<int>(
      tester,
      const ValueKey('recess-duration'),
      '10 minutes',
    );
    await select<ExerciseDifficulty>(
      tester,
      const ValueKey('exercise-difficulty'),
      'Challenging',
    );
    await select<BellSound>(
      tester,
      const ValueKey('bell-sound'),
      'Coach Whistle',
    );

    final saved = await database.preferences();
    expect(saved.durationMinutes, 10);
    expect(saved.exerciseDifficulty, ExerciseDifficulty.challenging);
    expect(saved.bellSound, BellSound.coachWhistle);
    expect(previewPlayer.played, [BellSound.coachWhistle]);
    expect(
      platformCalls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.selectionClick',
            ),
      ),
    );
  });

  testWidgets('persists quiet hours toggle and exposes both times',
      (tester) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('quiet-hours-toggle')),
      250,
    );

    await tester.tap(find.byKey(const ValueKey('quiet-hours-toggle')));
    await tester.pumpAndSettle();

    expect((await database.preferences()).quietHoursEnabled, isTrue);
    expect(find.byKey(const ValueKey('quiet-hours-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiet-hours-end')), findsOneWidget);
    expect(find.text('10:00 PM'), findsOneWidget);
    expect(find.text('7:00 AM'), findsOneWidget);
  });

  testWidgets('notification toggle persists and reuses permission request',
      (tester) async {
    await pumpSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notifications-toggle')));
    await tester.pumpAndSettle();
    expect((await database.preferences()).notificationsEnabled, isFalse);
    expect(notifications.permissionRequests, 0);

    await tester.ensureVisible(
      find.byKey(const ValueKey('notifications-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notifications-toggle')));
    await tester.pumpAndSettle();
    expect((await database.preferences()).notificationsEnabled, isTrue);
    expect(notifications.permissionRequests, 1);
  });

  testWidgets('preference controls reflow safely with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          notificationServiceProvider.overrideWithValue(notifications),
          bellPreviewPlayerProvider.overrideWithValue(previewPlayer),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Exercise difficulty'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
  });
}

class _FakePreviewPlayer implements BellPreviewPlayer {
  final played = <BellSound>[];

  @override
  Future<void> play(BellSound sound) async => played.add(sound);

  @override
  Future<void> stop() async {}
}

class _FakeNotifications implements BellNotifications {
  final _opened = StreamController<String>.broadcast();
  var permissionRequests = 0;

  Future<void> close() => _opened.close();

  @override
  Stream<String> get openedPayloads => _opened.stream;
  @override
  Future<void> cancelCadenceBell({Set<int> retaining = const {}}) async {}
  @override
  Future<void> cancelDeferredBell() async {}
  @override
  Future<List<PendingCadenceBell>> pendingCadenceBells() async => const [];
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

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
  }) async =>
      true;
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
