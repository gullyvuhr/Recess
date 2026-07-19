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
final exerciseProvider = FutureProvider.family<Exercise?, String>(
  (ref, id) => ref.watch(exerciseServiceProvider).findById(id),
);

class RecessActions {
  RecessActions(this.ref);

  final Ref ref;

  RecessSessionService get _service => ref.read(sessionServiceProvider);

  Future<RecessSession?> restore() => _service.restore();

  Future<RecessSession?> openBell(String payload) => _service.openBell(payload);

  Future<RecessSession> ringBellNow() => _service.ringBellNow();

  Future<RecessSession> start(int sessionId) async {
    final session = await _service.start(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(todayProgressProvider);
    return session;
  }

  Future<RecessSession> startNow() async {
    final session = await _service.startNow();
    ref.invalidate(todayProgressProvider);
    return session;
  }

  Future<RecessSession> defer(
    int sessionId,
    RecessDeferralType type,
  ) async {
    final session = await _service.defer(sessionId, type);
    ref.invalidate(sessionProvider(sessionId));
    return session;
  }

  Future<RecessSession> rainCheck(int sessionId) async {
    final session = await _service.rainCheck(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(todayProgressProvider);
    return session;
  }

  Future<RecessSession> complete(int sessionId) async {
    final session = await _service.complete(sessionId);
    ref.invalidate(sessionProvider(sessionId));
    ref.invalidate(todayProgressProvider);
    return session;
  }
}

final recessActionsProvider = Provider(RecessActions.new);
