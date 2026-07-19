import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'models.dart';
import 'notifications.dart';

export 'database.dart';
export 'notifications.dart';

final databaseProvider =
    Provider<RecessDatabase>((_) => throw UnimplementedError());
final notificationServiceProvider =
    Provider<NotificationService>((_) => throw UnimplementedError());

final scheduleProvider = FutureProvider<WorkSchedule?>(
    (ref) => ref.watch(databaseProvider).schedule());
final todayProgressProvider = FutureProvider<TodayProgress>(
    (ref) => ref.watch(databaseProvider).todayProgress());

class RecessActions {
  RecessActions(this.ref);
  final Ref ref;

  Future<void> start() async {
    await ref.read(databaseProvider).addEntry(RecessStatus.started);
    ref.invalidate(todayProgressProvider);
  }

  Future<void> complete() async {
    await ref.read(databaseProvider).addEntry(RecessStatus.completed);
    ref.invalidate(todayProgressProvider);
  }

  Future<void> rainCheck() async {
    await ref.read(databaseProvider).addEntry(RecessStatus.rainCheck);
    ref.invalidate(todayProgressProvider);
  }
}

final recessActionsProvider = Provider(RecessActions.new);
