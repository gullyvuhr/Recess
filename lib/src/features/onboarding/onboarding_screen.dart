import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _redirectIfComplete();
  }

  Future<void> _redirectIfComplete() async {
    final schedule = await ref.read(databaseProvider).schedule();
    if (!mounted) return;
    if (schedule != null) {
      context.go('/home');
    } else {
      setState(() => _checking = false);
    }
  }

  Future<void> _pick(bool start) async {
    final value = await showTimePicker(
        context: context, initialTime: start ? _start : _end);
    if (value == null) return;
    setState(() => start ? _start = value : _end = value);
  }

  Future<void> _continue() async {
    final start = _start.hour * 60 + _start.minute;
    final end = _end.hour * 60 + _end.minute;
    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work end must be after work start.')));
      return;
    }
    final schedule = WorkSchedule(startMinutes: start, endMinutes: end);
    await ref.read(databaseProvider).saveSchedule(schedule);
    try {
      await ref.read(notificationServiceProvider).scheduleBell(schedule);
    } catch (_) {
      // Saving onboarding should still succeed when notifications are denied.
    }
    ref.invalidate(scheduleProvider);
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.park_outlined,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text('Make room for recess.',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                  'A gentle, private nudge to step away during your workday. Everything stays on this device.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center),
              const Spacer(),
              Text('Your usual workday',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _TimeCard(
                          label: 'Starts',
                          time: _start,
                          onTap: () => _pick(true))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _TimeCard(
                          label: 'Ends',
                          time: _end,
                          onTap: () => _pick(false))),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _continue,
                  child: const Padding(
                      padding: EdgeInsets.all(12), child: Text('Begin'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard(
      {required this.label, required this.time, required this.onTap});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label),
              const SizedBox(height: 6),
              Text(time.format(context),
                  style: Theme.of(context).textTheme.titleLarge)
            ]),
          ),
        ),
      );
}
