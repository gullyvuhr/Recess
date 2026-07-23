import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/bell_audio.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const appVersion = '1.0.0-rc.1';
  static const buildNumber = '4';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final schedule = ref.watch(scheduleProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: preferences.when(
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _SectionLabel('Workday'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Workday schedule'),
              subtitle:
                  Text(_scheduleDescription(context, schedule.valueOrNull)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/onboarding?edit=true'),
            ),
            const Divider(),
            const _SectionLabel('Recess'),
            _PreferenceDropdown<int>(
              key: const ValueKey('recess-duration'),
              icon: Icons.timer_outlined,
              title: 'Duration',
              value: value.durationMinutes,
              items: {
                for (final minutes in RecessPreferences.supportedDurations)
                  minutes: '$minutes minutes',
              },
              onChanged: (duration) => _save(
                ref,
                value.copyWith(durationMinutes: duration),
              ),
            ),
            _PreferenceDropdown<ExerciseDifficulty>(
              key: const ValueKey('exercise-difficulty'),
              icon: Icons.fitness_center_outlined,
              title: 'Exercise difficulty',
              value: value.exerciseDifficulty,
              items: const {
                ExerciseDifficulty.easy: 'Easy',
                ExerciseDifficulty.standard: 'Standard',
                ExerciseDifficulty.challenging: 'Challenging',
              },
              onChanged: (difficulty) => _save(
                ref,
                value.copyWith(exerciseDifficulty: difficulty),
              ),
            ),
            _PreferenceDropdown<BellSound>(
              key: const ValueKey('bell-sound'),
              icon: Icons.notifications_active_outlined,
              title: 'Bell sound',
              value: value.bellSound,
              items: {
                for (final sound in BellSound.values)
                  sound: sound.definition.label,
              },
              onChanged: (sound) async {
                await _save(ref, value.copyWith(bellSound: sound));
                unawaited(
                  HapticFeedback.selectionClick().catchError((_) {}),
                );
                await ref.read(bellPreviewPlayerProvider).play(sound);
                await ref.read(recessActionsProvider).refreshBellSound();
              },
            ),
            const Divider(),
            const _SectionLabel('Quiet hours'),
            SwitchListTile(
              key: const ValueKey('quiet-hours-toggle'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.bedtime_outlined),
              title: const Text('Quiet hours'),
              subtitle: const Text(
                'Scheduled Bells in this time are skipped.',
              ),
              value: value.quietHoursEnabled,
              onChanged: (enabled) => _saveQuietHours(
                ref,
                value.copyWith(quietHoursEnabled: enabled),
              ),
            ),
            if (value.quietHoursEnabled) ...[
              ListTile(
                key: const ValueKey('quiet-hours-start'),
                contentPadding: const EdgeInsets.only(left: 40),
                title: const Text('Starts'),
                trailing: Text(_time(context, value.quietHoursStartMinutes)),
                onTap: () => _pickTime(
                  context,
                  ref,
                  value,
                  start: true,
                ),
              ),
              ListTile(
                key: const ValueKey('quiet-hours-end'),
                contentPadding: const EdgeInsets.only(left: 40),
                title: const Text('Ends'),
                trailing: Text(_time(context, value.quietHoursEndMinutes)),
                onTap: () => _pickTime(
                  context,
                  ref,
                  value,
                  start: false,
                ),
              ),
            ],
            const Divider(),
            const _SectionLabel('Notifications'),
            SwitchListTile(
              key: const ValueKey('notifications-toggle'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(
                value.notificationsEnabled
                    ? 'Notifications on'
                    : 'Notifications off',
              ),
              value: value.notificationsEnabled,
              onChanged: (enabled) => _setNotifications(
                context,
                ref,
                value,
                enabled,
              ),
            ),
            const Divider(),
            const _SectionLabel('About'),
            const _AboutRecess(),
            const SizedBox(height: 8),
            Text(
              'Release candidate · Version $appVersion ($buildNumber) · Offline First',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Settings are unavailable.'),
        ),
      ),
    );
  }

  static String _scheduleDescription(
    BuildContext context,
    WorkSchedule? schedule,
  ) {
    if (schedule == null) return 'Set your usual workday';
    return '${_time(context, schedule.startMinutes)} to '
        '${_time(context, schedule.endMinutes)} · '
        'Bells every ${schedule.cadenceMinutes} minutes';
  }

  static String _time(BuildContext context, int minutes) => TimeOfDay(
        hour: minutes ~/ 60,
        minute: minutes % 60,
      ).format(context);

  static Future<void> _save(
    WidgetRef ref,
    RecessPreferences preferences,
  ) =>
      ref.read(preferencesActionsProvider).save(preferences);

  static Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    RecessPreferences preferences, {
    required bool start,
  }) async {
    final current = start
        ? preferences.quietHoursStartMinutes
        : preferences.quietHoursEndMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected == null) return;
    final minutes = selected.hour * 60 + selected.minute;
    await _saveQuietHours(
      ref,
      start
          ? preferences.copyWith(quietHoursStartMinutes: minutes)
          : preferences.copyWith(quietHoursEndMinutes: minutes),
    );
  }

  static Future<void> _saveQuietHours(
    WidgetRef ref,
    RecessPreferences preferences,
  ) async {
    await _save(ref, preferences);
    await ref.read(recessActionsProvider).restore();
  }

  static Future<void> _setNotifications(
    BuildContext context,
    WidgetRef ref,
    RecessPreferences preferences,
    bool enabled,
  ) async {
    var savedValue = enabled;
    if (enabled) {
      savedValue =
          await ref.read(notificationServiceProvider).requestPermission();
    }
    await _save(
      ref,
      preferences.copyWith(notificationsEnabled: savedValue),
    );
    if (enabled && !savedValue && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications remain off in device settings.'),
        ),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _PreferenceDropdown<T> extends StatelessWidget {
  const _PreferenceDropdown({
    required super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (!largeText) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        trailing: _dropdown(),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(icon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title),
                SizedBox(
                  width: double.infinity,
                  child: _dropdown(expanded: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({bool expanded = false}) => DropdownButton<T>(
        value: value,
        isExpanded: expanded,
        underline: const SizedBox.shrink(),
        items: items.entries
            .map(
              (entry) => DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(growable: false),
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      );
}

class _AboutRecess extends StatelessWidget {
  const _AboutRecess();

  @override
  Widget build(BuildContext context) => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.park_outlined),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Recess is a quiet reminder to step away from work and make time for yourself. '
              'It exists because small breaks are easy to postpone. '
              'Everything works offline, with no account or cloud dependency. '
              'Recess has no analytics and does not collect or send personal data. '
              'Your settings and history stay on this device. '
              'The simplicity is intentional: fewer distractions, more room to take a break.',
            ),
          ),
        ],
      );
}
