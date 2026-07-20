import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exercises/exercise.dart';
import '../exercises/exercise_repository.dart';
import '../exercises/exercise_service.dart';
import 'database.dart';
import 'history.dart';
import 'models.dart';
import 'notifications.dart';
import 'session_service.dart';

export 'database.dart';
export 'notifications.dart';

final databaseProvider =
    Provider<RecessDatabase>((_) => throw UnimplementedError());
final notificationServiceProvider =
    Provider<BellNotifications>((_) => throw UnimplementedError());
final exerciseCatalogProvider = Provider<ExerciseCatalog>(
  (_) => AssetExerciseRepository(),
);
final exerciseServiceProvider = Provider(
  (ref) => ExerciseService(catalog: ref.watch(exerciseCatalogProvider)),
);
final clockProvider = Provider<Clock>((_) => DateTime.now);

final historyNowProvider = Provider<DateTime>((_) => DateTime.now());
final historyServiceProvider = Provider(
  (ref) => HistoryService(
    database: ref.watch(databaseProvider),
    exercises: ref.watch(exerciseCatalogProvider),
  ),
);

class HistoryPeriodController extends StateNotifier<HistoryPeriod> {
  HistoryPeriodController(this.now) : super(HistoryPeriod.current(now));

  final DateTime now;

  void previous() => state = state.previous();
  void next() => state = state.next(now);
}

final historyPeriodProvider =
    StateNotifierProvider.autoDispose<HistoryPeriodController, HistoryPeriod>(
  (ref) => HistoryPeriodController(ref.watch(historyNowProvider)),
);
final historyProvider =
    FutureProvider.autoDispose.family<HistoryData, HistoryPeriod>(
  (ref, period) => ref.watch(historyServiceProvider).load(period),
);

final sessionServiceProvider = Provider(
  (ref) => RecessSessionService(
    database: ref.watch(databaseProvider),
    notifications: ref.watch(notificationServiceProvider),
    exercises: ref.watch(exerciseServiceProvider),
    clock: ref.watch(clockProvider),
  ),
);

final scheduleProvider = FutureProvider<WorkSchedule?>(
  (ref) => ref.watch(databaseProvider).schedule(),
);
final todayProgressProvider = FutureProvider<TodayProgress>(
  (ref) => ref.watch(databaseProvider).todayProgress(),
);
final sessionProvider = FutureProvider.family<RecessSession?, int>(
  (ref, id) => ref.watch(databaseProvider).session(id),
);
final openSessionProvider = FutureProvider<RecessSession?>(
  (ref) => ref.watch(databaseProvider).openSession(),
);
final homeRecessStatusProvider = FutureProvider<HomeRecessStatus?>((ref) async {
  final schedule = await ref.watch(scheduleProvider.future);
  if (schedule == null) return null;

  final session = await ref.watch(openSessionProvider.future);
  if (session?.status == RecessSessionStatus.active) {
    return const HomeRecessStatus(HomeRecessState.active);
  }
  final now = ref.watch(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  if (session != null &&
      (session.status == RecessSessionStatus.scheduled ||
          session.status == RecessSessionStatus.deferred) &&
      session.workdayDate == today) {
    return HomeRecessStatus(
      HomeRecessState.scheduled,
      scheduledAt: session.scheduledAt,
    );
  }
  return const HomeRecessStatus(HomeRecessState.noMoreToday);
});
final exerciseProvider = FutureProvider.family<Exercise?, String>(
  (ref, id) => ref.watch(exerciseServiceProvider).findById(id),
);

class RecessActions {
  RecessActions(this.ref);

  final Ref ref;

  RecessSessionService get _service => ref.read(sessionServiceProvider);

  Future<SessionActionResult<RecessSession?>> restore() async {
    final result = await _service.restore();
    ref.invalidate(scheduleProvider);
    ref.invalidate(openSessionProvider);
    return result;
  }

  Future<SessionActionResult<RecessSession?>> saveSchedule(
    WorkSchedule schedule,
  ) async {
    final result = await _service.saveSchedule(schedule);
    ref.invalidate(scheduleProvider);
    ref.invalidate(openSessionProvider);
    return result;
  }

  Future<RecessSession?> openBell(String payload) => _service.openBell(payload);

  Future<SessionActionResult<RecessSession>> ringBellNow() async {
    final result = await _service.ringBellNow();
    ref.invalidate(openSessionProvider);
    return result;
  }

  Future<RecessSession> start(int sessionId) async {
    final session = await _service.start(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(openSessionProvider);
    ref.invalidate(todayProgressProvider);
    ref.invalidate(historyProvider);
    return session;
  }

  Future<RecessSession> startNow() async {
    final session = await _service.startNow();
    ref.invalidate(todayProgressProvider);
    ref.invalidate(openSessionProvider);
    ref.invalidate(historyProvider);
    return session;
  }

  Future<SessionActionResult<RecessSession>> defer(
    int sessionId,
    RecessDeferralType type,
  ) async {
    final result = await _service.defer(sessionId, type);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(openSessionProvider);
    ref.invalidate(historyProvider);
    return result;
  }

  Future<SessionActionResult<RecessSession>> rainCheck(int sessionId) async {
    final result = await _service.rainCheck(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(todayProgressProvider);
    ref.invalidate(openSessionProvider);
    ref.invalidate(historyProvider);
    return result;
  }

  Future<SessionActionResult<RecessSession>> complete(int sessionId) async {
    final result = await _service.complete(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(todayProgressProvider);
    ref.invalidate(openSessionProvider);
    ref.invalidate(historyProvider);
    return result;
  }
}

final recessActionsProvider = Provider(RecessActions.new);
