import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/insights.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

String formatRecessCountdown(DateTime scheduledAt, DateTime now) {
  final remaining = scheduledAt.difference(now);
  if (remaining <= Duration.zero) return 'Ready when you are';
  if (remaining.inSeconds < 60) return 'In less than a minute';
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  if (hours == 0) return 'In $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  if (minutes == 0) return 'In $hours ${hours == 1 ? 'hour' : 'hours'}';
  return 'In $hours hr $minutes min';
}

String formatTodayProgress(TodayInsightMetrics metrics) {
  final completed = metrics.completed;
  final movementMinutes = metrics.completedMovementDuration.inMinutes;
  return '$completed ${completed == 1 ? 'recess' : 'recesses'} · '
      '$movementMinutes movement ${movementMinutes == 1 ? 'minute' : 'minutes'}';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _acting = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    final schedule = ref.watch(scheduleProvider);
    final homeStatus = ref.watch(homeRecessStatusProvider);
    final insights = ref.watch(insightProvider);
    final openSessionState = ref.watch(openSessionProvider);
    final hasActiveSession =
        openSessionState.valueOrNull?.status == RecessSessionStatus.active;

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
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(scheduleProvider);
          ref.invalidate(openSessionProvider);
          ref.invalidate(insightProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            _NextRecessHero(
              schedule: schedule,
              status: homeStatus,
              now: ref.watch(clockProvider)(),
              acting: _acting,
              loadingSession: openSessionState.isLoading,
              hasActiveSession: hasActiveSession,
              onStart: _startRecess,
              onRing: _ringBells,
              onConfigure: () => context.go('/onboarding?edit=true'),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _SectionTitle('Today'),
            const SizedBox(height: 6),
            insights.when(
              data: (value) => _TodayProgress(metrics: value.today),
              loading: () => const _LoadingBlock(),
              error: (_, __) => const Text('Today\'s progress is unavailable.'),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _SectionTitle('Insight'),
            const SizedBox(height: 6),
            insights.when(
              data: (value) => _HomeInsight(summary: value),
              loading: () => const _LoadingBlock(),
              error: (_, __) => const Text('Insight is unavailable.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextRecessHero extends StatelessWidget {
  const _NextRecessHero({
    required this.schedule,
    required this.status,
    required this.now,
    required this.acting,
    required this.loadingSession,
    required this.hasActiveSession,
    required this.onStart,
    required this.onRing,
    required this.onConfigure,
  });

  final AsyncValue<WorkSchedule?> schedule;
  final AsyncValue<HomeRecessStatus?> status;
  final DateTime now;
  final bool acting;
  final bool loadingSession;
  final bool hasActiveSession;
  final VoidCallback onStart;
  final VoidCallback onRing;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final configured = schedule.valueOrNull != null;
    final current = status.valueOrNull;
    final scheduledAt = current?.scheduledAt;
    final active = current?.state == HomeRecessState.active;
    final loading = schedule.isLoading || status.isLoading;
    final title = loading
        ? 'Finding your next Recess'
        : !configured
            ? 'Set your workday'
            : active
                ? 'Recess in progress'
                : scheduledAt != null
                    ? null
                    : 'All done for today';
    final detail = loading
        ? 'Just a moment'
        : !configured
            ? 'Choose when Bells should gently arrive.'
            : active
                ? 'Take the time you need.'
                : scheduledAt != null
                    ? formatRecessCountdown(scheduledAt, now)
                    : 'There are no more scheduled Recesses today.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'NEXT RECESS',
            style: Theme.of(context).textTheme.labelMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (scheduledAt != null && !active)
            _ScheduledTime(scheduledAt: scheduledAt)
          else
            Text(
              title!,
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 14),
          if (scheduledAt != null && !active) ...[
            Text(
              'Your next Recess is in',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              _countdownValue(detail),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ] else
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!configured && !loading)
                    FilledButton.icon(
                      onPressed: onConfigure,
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Set schedule'),
                      ),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: acting || loadingSession ? null : onStart,
                      icon: Icon(
                        active ? Icons.play_arrow : Icons.directions_walk,
                      ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(active ? 'Resume Recess' : 'Start Now'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: acting || loadingSession || hasActiveSession
                          ? null
                          : onRing,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Bells'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _countdownValue(String value) =>
      value.startsWith('In ') ? value.substring(3) : value;
}

class _ScheduledTime extends StatelessWidget {
  const _ScheduledTime({required this.scheduledAt});

  final DateTime scheduledAt;

  @override
  Widget build(BuildContext context) {
    final use24HourTime = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = TimeOfDay.fromDateTime(scheduledAt);
    final hour = use24HourTime
        ? time.hour.toString().padLeft(2, '0')
        : time.hourOfPeriod.toString();
    final value = '$hour:${time.minute.toString().padLeft(2, '0')}';
    final period = use24HourTime
        ? null
        : time.period == DayPeriod.am
            ? MaterialLocalizations.of(context).anteMeridiemAbbreviation
            : MaterialLocalizations.of(context).postMeridiemAbbreviation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveSize =
            (constraints.maxWidth * 0.22).clamp(56.0, 82.0).toDouble();
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: responsiveSize,
                      height: 1,
                    ),
              ),
              if (period != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    period,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TodayProgress extends StatelessWidget {
  const _TodayProgress({required this.metrics});
  final TodayInsightMetrics metrics;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(formatTodayProgress(metrics))),
          ],
        ),
      );
}

class _HomeInsight extends StatelessWidget {
  const _HomeInsight({required this.summary});
  final InsightSummary summary;

  @override
  Widget build(BuildContext context) {
    final observation = summary.observations.firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(observation?.description ??
                'A useful observation will appear as your Recess history grows.'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
}
