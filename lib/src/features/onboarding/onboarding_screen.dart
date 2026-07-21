import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.editing = false, super.key});

  final bool editing;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  int _cadenceMinutes = 60;
  bool _checking = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final schedule = await ref.read(databaseProvider).schedule();
    if (!mounted) return;
    if (schedule != null && !widget.editing) {
      context.go('/home');
    } else {
      setState(() {
        if (schedule != null) {
          _start = TimeOfDay(
            hour: schedule.startMinutes ~/ 60,
            minute: schedule.startMinutes % 60,
          );
          _end = TimeOfDay(
            hour: schedule.endMinutes ~/ 60,
            minute: schedule.endMinutes % 60,
          );
          _cadenceMinutes = schedule.cadenceMinutes;
        }
        _checking = false;
      });
    }
  }

  Future<void> _pick(bool start) async {
    final value = await showTimePicker(
        context: context, initialTime: start ? _start : _end);
    if (value == null) return;
    setState(() => start ? _start = value : _end = value);
  }

  Future<void> _continue() async {
    if (_saving) return;
    final start = _start.hour * 60 + _start.minute;
    final end = _end.hour * 60 + _end.minute;
    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work end must be after work start.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final schedule = WorkSchedule(
        startMinutes: start,
        endMinutes: end,
        cadenceMinutes: _cadenceMinutes,
      );
      var permissionGranted = true;
      if (!widget.editing) {
        final shouldRequest = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('A gentle reminder'),
                content: const Text(
                  'Recess uses notifications to ring the Bells during your workday. You can still use Recess if you choose not to allow them.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ) ??
            false;
        permissionGranted = shouldRequest &&
            await ref.read(notificationServiceProvider).requestPermission();
      }
      final restored =
          await ref.read(recessActionsProvider).saveSchedule(schedule);
      if (!mounted) return;
      if (!permissionGranted || !restored.notificationSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are off. Recess still works when you open the app.',
            ),
          ),
        );
      }
      context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recess could not finish setup. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: widget.editing
          ? AppBar(
              title: const Text('Workday'),
              backgroundColor: Colors.transparent,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
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
                    IgnorePointer(
                      ignoring: _saving,
                      child: Row(
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
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'How often should Bells ring?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: const ValueKey('bell-cadence'),
                      initialValue: _cadenceMinutes,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [30, 45, 60, 90, 120]
                          .map(
                            (minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text('Every $minutes minutes'),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _cadenceMinutes = value);
                              }
                            },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: _saving ? null : _continue,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Save schedule'),
                        )),
                  ],
                ),
              ),
            ),
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label, ${time.format(context)}',
        onTap: onTap,
        excludeSemantics: true,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  const SizedBox(height: 6),
                  Text(
                    time.format(context),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
