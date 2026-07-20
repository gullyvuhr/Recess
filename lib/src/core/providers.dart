import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exercises/exercise.dart';
import '../exercises/exercise_repository.dart';
import '../exercises/exercise_service.dart';
import 'database.dart';
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

final sessionServiceProvider = Provider(
  (ref) => RecessSessionService(
    database: ref.watch(databaseProvider),
    notifications: ref.watch(notificationServiceProvider),
    exercises: ref.watch(exerciseServiceProvider),
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
final exerciseProvider = FutureProvider.family<Exercise?, String>(
  (ref, id) => ref.watch(exerciseServiceProvider).findById(id),
);

class RecessActions {
  RecessActions(this.ref);

  final Ref ref;

  RecessSessionService get _service => ref.read(sessionServiceProvider);

  Future<SessionActionResult<RecessSession?>> restore() => _service.restore();

  Future<SessionActionResult<RecessSession?>> saveSchedule(
    WorkSchedule schedule,
  ) async {
    final result = await _service.saveSchedule(schedule);
    ref.invalidate(scheduleProvider);
    ref.invalidate(openSessionProvider);
    return result;
  }

  Future<RecessSession?> openBell(String payload) => _service.openBell(payload);

  Future<SessionActionResult<RecessSession>> ringBellNow() =>
      _service.ringBellNow();

  Future<RecessSession> start(int sessionId) async {
    final session = await _service.start(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(openSessionProvider);
    ref.invalidate(todayProgressProvider);
    return session;
  }

  Future<RecessSession> startNow() async {
    final session = await _service.startNow();
    ref.invalidate(todayProgressProvider);
    ref.invalidate(openSessionProvider);
    return session;
  }

  Future<SessionActionResult<RecessSession>> defer(
    int sessionId,
    RecessDeferralType type,
  ) async {
    final result = await _service.defer(sessionId, type);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(openSessionProvider);
    return result;
  }

  Future<SessionActionResult<RecessSession>> rainCheck(int sessionId) async {
    final result = await _service.rainCheck(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(todayProgressProvider);
    ref.invalidate(openSessionProvider);
    return result;
  }

  Future<SessionActionResult<RecessSession>> complete(int sessionId) async {
    final result = await _service.complete(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(todayProgressProvider);
    ref.invalidate(openSessionProvider);
    return result;
  }
}

final recessActionsProvider = Provider(RecessActions.new);
