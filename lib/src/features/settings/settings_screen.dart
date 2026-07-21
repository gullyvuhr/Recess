import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const appVersion = '0.1.0';
  static const buildNumber = '1';

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
              items: const {
                BellSound.schoolBell: 'School Bell',
                BellSound.coachWhistle: 'Coach Whistle',
                BellSound.gentleChime: 'Gentle Chime',
              },
              onChanged: (sound) => _save(
                ref,
                value.copyWith(bellSound: sound),
              ),
            ),
            const Divider(),
            const _SectionLabel('Quiet hours'),
            SwitchListTile(
              key: const ValueKey('quiet-hours-toggle'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.bedtime_outlined),
              title: const Text('Quiet hours'),
              subtitle: const Text('Keep this preference on this device'),
              value: value.quietHoursEnabled,
              onChanged: (enabled) => _save(
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
                    ? 'Notifications On'
                    : 'Notifications Off',
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
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.park_outlined),
              title: Text('Recess'),
              subtitle:
                  Text('Version $appVersion ($buildNumber)\nOffline First'),
              isThreeLine: true,
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
    await _save(
      ref,
      start
          ? preferences.copyWith(quietHoursStartMinutes: minutes)
          : preferences.copyWith(quietHoursEndMinutes: minutes),
    );
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
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        trailing: DropdownButton<T>(
          value: value,
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
        ),
      );
}
