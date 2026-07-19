import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(todayProgressProvider);
    final schedule = ref.watch(scheduleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recess'), backgroundColor: Colors.transparent),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todayProgressProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('How about a little space?', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            schedule.when(
              data: (value) => Text(value == null ? 'Set a work schedule' : 'Your workday is ${_time(context, value.startMinutes)}–${_time(context, value.endMinutes)}.'),
              loading: () => const Text('Loading your schedule…'),
              error: (_, __) => const Text('Schedule unavailable'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await ref.read(notificationServiceProvider).ringBells();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The bells rang.')));
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Padding(padding: EdgeInsets.all(14), child: Text('Bells')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(recessActionsProvider).start();
                if (context.mounted) context.go('/recess');
              },
              icon: const Icon(Icons.directions_walk),
              label: const Padding(padding: EdgeInsets.all(14), child: Text('Start Recess')),
            ),
            const SizedBox(height: 28),
            Text("Today's progress", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            progress.when(
              data: (value) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _Stat(value: value.started, label: 'Started'),
                    _Stat(value: value.completed, label: 'Finished'),
                    _Stat(value: value.rainChecks, label: 'Rain checks'),
                  ]),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Progress unavailable'),
            ),
            const SizedBox(height: 18),
            Text('No streaks. No guilt. Just the next good moment.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _time(BuildContext context, int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [Text('$value', style: Theme.of(context).textTheme.headlineMedium), Text(label)]);
}

