import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/home/home_screen.dart';
import 'features/history/history_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/recess/bell_response_screen.dart';
import 'features/recess/recess_screen.dart';
import 'features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, state) => OnboardingScreen(
          editing: state.uri.queryParameters['edit'] == 'true',
        ),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/bell/:sessionId',
        builder: (_, state) => BellResponseScreen(
          sessionId: int.parse(state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/recess/:sessionId',
        builder: (_, state) => RecessScreen(
          sessionId: int.parse(state.pathParameters['sessionId']!),
        ),
      ),
    ],
  );
});

class RecessApp extends ConsumerStatefulWidget {
  const RecessApp({super.key});

  @override
  ConsumerState<RecessApp> createState() => _RecessAppState();
}

class _RecessAppState extends ConsumerState<RecessApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(notificationServiceProvider);
    _notificationSubscription = notifications.openedPayloads.listen((payload) {
      unawaited(_openBell(payload));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialPayload = notifications.takeInitialPayload();
      await ref.read(recessActionsProvider).restore();
      if (initialPayload != null) {
        await _openBell(initialPayload);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileAfterResume());
    }
  }

  Future<void> _reconcileAfterResume() async {
    final notifications = ref.read(notificationServiceProvider);
    if (notifications is NotificationService) {
      await notifications.refreshTimezone();
    }
    await ref.read(recessActionsProvider).restore();
  }

  Future<bool> _openBell(String payload) async {
    final session = await ref.read(recessActionsProvider).openBell(payload);
    if (session != null && mounted) {
      ref.read(routerProvider).go('/bell/${session.id}');
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff315c4b);
    return MaterialApp.router(
      title: 'Recess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7f3e8),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      ),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
