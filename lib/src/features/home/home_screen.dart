import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/insights.dart';
import '../../core/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _acting = false;

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _ringBells() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final result = await ref.read(recessActionsProvider).ringBellNow();
      if (!mounted) return;
      _message(result.notificationSucceeded
          ? 'The Bells rang.'
          : 'Recess could not deliver a notification. Check notification permissions.');
    } catch (_) {
      if (mounted) {
        _message('Recess could not ring the Bells. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _startRecess() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final session = await ref.read(recessActionsProvider).startNow();
      if (mounted) context.go('/recess/${session.id}');
    } catch (_) {
      if (mounted) _message('Recess could not start. Please try again.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(todayProgressProvider);
    final schedule = ref.watch(scheduleProvider);
    final homeStatus = ref.watch(homeRecessStatusProvider);
    final insights = ref.watch(insightProvider);
    final openSessionState = ref.watch(openSessionProvider);
    final openSession = openSessionState.valueOrNull;
    final hasActiveSession = openSession?.status == RecessSessionStatus.active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recess'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Edit work schedule',
            onPressed: () => context.go('/onboarding?edit=true'),
            icon: const Icon(Icons.schedule_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayProgressProvider);
          ref.invalidate(scheduleProvider);
          ref.invalidate(openSessionProvider);
          ref.invalidate(insightProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('How about a little space?',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            schedule.when(
              data: (value) => value == null
                  ? const Text('Set a work schedule')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your workday is ${_time(context, value.startMinutes)}–${_time(context, value.endMinutes)}.',
                        ),
                        const SizedBox(height: 4),
                        homeStatus.when(
                          data: (status) => Text(_nextRecess(context, status)),
                          loading: () => const Text('Loading next Recess…'),
                          error: (_, __) => const Text(
                            'No more Recesses scheduled today',
                          ),
                        ),
                      ],
                    ),
              loading: () => const Text('Loading your schedule…'),
              error: (_, __) => const Text('Schedule unavailable'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  _acting || openSessionState.isLoading || hasActiveSession
                      ? null
                      : _ringBells,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Padding(
                  padding: EdgeInsets.all(14), child: Text('Bells')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _acting || openSessionState.isLoading ? null : _startRecess,
              icon: const Icon(Icons.directions_walk),
              label: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  openSessionState.isLoading
                      ? 'Loading Recess…'
                      : hasActiveSession
                          ? 'Resume Recess'
                          : 'Start Recess',
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text("Today's progress",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            progress.when(
              data: (value) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(value: value.started, label: 'Started'),
                        _Stat(value: value.completed, label: 'Completed'),
                        _Stat(
                          value: insights.valueOrNull?.today.deferred ??
                              value.rainChecks,
                          label: 'Deferred',
                        ),
                      ]),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Progress unavailable'),
            ),
            const SizedBox(height: 28),
            Text('Insights', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            insights.when(
              data: (value) => _HomeInsight(summary: value),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Insights unavailable'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/history'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(BuildContext context, int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  String _nextRecess(BuildContext context, HomeRecessStatus? status) {
    if (status == null || status.state == HomeRecessState.noMoreToday) {
      return 'No more Recesses scheduled today';
    }
    if (status.state == HomeRecessState.active) return 'Recess in progress';
    return 'Next Recess: ${TimeOfDay.fromDateTime(status.scheduledAt!).format(context)}';
  }
}

class _HomeInsight extends StatelessWidget {
  const _HomeInsight({required this.summary});

  final InsightSummary summary;

  @override
  Widget build(BuildContext context) {
    final observation = summary.observations.firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          observation?.description ??
              'More insights will appear as Recess remembers your activity.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('$value', style: Theme.of(context).textTheme.headlineMedium),
        Text(label)
      ]);
}
