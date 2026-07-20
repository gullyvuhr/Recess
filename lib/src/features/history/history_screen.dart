import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(historyPeriodProvider);
    final history = ref.watch(historyProvider(period));
    final now = ref.watch(historyNowProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(historyProvider(period).future),
        child: history.when(
          data: (data) => _HistoryBody(
            data: data,
            canMoveNext: period.canMoveNext(now),
            onPrevious: () =>
                ref.read(historyPeriodProvider.notifier).previous(),
            onNext: () => ref.read(historyPeriodProvider.notifier).next(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Center(child: Text('History is unavailable right now.')),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.data,
    required this.canMoveNext,
    required this.onPrevious,
    required this.onNext,
  });

  final HistoryData data;
  final bool canMoveNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('previous-history-period'),
                tooltip: 'Previous seven days',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_shortDate(data.period.start)} – ${_shortDate(data.period.endInclusive)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const ValueKey('next-history-period'),
                tooltip: 'Next seven days',
                onPressed: canMoveNext ? onNext : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WeeklySummary(summary: data.summary),
          const SizedBox(height: 24),
          Text('Daily activity', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (data.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No Recess history for these seven days.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...data.days.map(_DayCard.new),
        ],
      );
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({required this.summary});

  final HistorySummary summary;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seven-day summary',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              Wrap(
                spacing: 20,
                runSpacing: 16,
                children: [
                  _SummaryValue('Completed Recesses', '${summary.completed}'),
                  _SummaryValue('Deferred Recesses', '${summary.deferred}'),
                  _SummaryValue('Rain checks', '${summary.rainChecked}'),
                  _SummaryValue(
                    'Average duration',
                    _duration(summary.averageDuration),
                  ),
                  _SummaryValue(
                    'Average response delay',
                    _duration(summary.averageResponseDelay),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard(this.day);

  final HistoryDay day;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(_longDate(day.date)),
          subtitle: Text(
            '${day.completed} completed · ${day.deferred} deferred · ${day.rainChecked} rain checked',
          ),
          children: [
            for (final item in day.sessions) _SessionRow(item: item),
          ],
        ),
      );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.item});

  final HistorySession item;

  @override
  Widget build(BuildContext context) {
    final session = item.session;
    final details = <String>[
      if (session.startedAt != null)
        'Started ${_time(context, session.startedAt!)}',
      if (session.completedAt != null)
        'Completed ${_time(context, session.completedAt!)}',
      if (session.completedDuration != null)
        'Duration ${_duration(session.completedDuration)}',
      if (session.responseDelay != null)
        'Response ${_duration(session.responseDelay)}',
      if (item.exerciseName != null) item.exerciseName!,
      if (session.deferralCount > 0)
        'Deferred ${session.deferralCount} ${session.deferralCount == 1 ? 'time' : 'times'}',
    ];
    return ListTile(
      key: ValueKey('history-session-${session.id}'),
      leading: Text(
        _time(context, session.originalScheduledAt),
        style: Theme.of(context).textTheme.labelLarge,
      ),
      title: Text(_status(session.status)),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      isThreeLine: details.length > 2,
    );
  }
}

String _status(RecessSessionStatus status) => switch (status) {
      RecessSessionStatus.completed => 'Completed',
      RecessSessionStatus.deferred => 'Deferred',
      RecessSessionStatus.rainChecked => 'Rain checked',
      RecessSessionStatus.scheduled => 'Scheduled',
      RecessSessionStatus.active => 'Active',
    };

String _duration(Duration? duration) {
  if (duration == null) return '—';
  final totalSeconds = duration.inSeconds;
  if (totalSeconds < 60) return '${totalSeconds}s';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
}

String _time(BuildContext context, DateTime value) =>
    TimeOfDay.fromDateTime(value).format(context);

String _shortDate(DateTime value) => '${_months[value.month - 1]} ${value.day}';

String _longDate(DateTime value) =>
    '${_weekdays[value.weekday - 1]}, ${_months[value.month - 1]} ${value.day}';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];
