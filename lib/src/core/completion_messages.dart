class CompletionMessage {
  const CompletionMessage({
    required this.primary,
    required this.supporting,
  });

  final String primary;
  final String supporting;
}

class CompletionMessageContext {
  const CompletionMessageContext({
    required this.selectionSeed,
    this.completedCountToday,
    this.movementMinutesToday,
    this.nextScheduledTime,
    this.isFinalScheduledRecess = false,
    this.isManualSession = false,
    this.previousPrimary,
  });

  final int selectionSeed;
  final int? completedCountToday;
  final int? movementMinutesToday;
  final String? nextScheduledTime;
  final bool isFinalScheduledRecess;
  final bool isManualSession;
  final String? previousPrimary;
}

class CompletionMessageFormatter {
  const CompletionMessageFormatter();

  static const primaryMessages = [
    'Nice work.',
    'Well done.',
    'You showed up.',
    'Good choice.',
    'That one was for you.',
    'Small wins count.',
    'Your body noticed.',
    'You made time for yourself.',
  ];

  CompletionMessage format(CompletionMessageContext context) {
    var index = context.selectionSeed.abs() % primaryMessages.length;
    if (primaryMessages[index] == context.previousPrimary) {
      index = (index + 1) % primaryMessages.length;
    }
    return CompletionMessage(
      primary: primaryMessages[index],
      supporting: _supporting(context),
    );
  }

  String _supporting(CompletionMessageContext context) {
    final completed = context.completedCountToday;
    if (completed != null && completed > 1) {
      return 'That\'s your ${_ordinal(completed)} Recess today.';
    }
    final movementMinutes = context.movementMinutesToday;
    if (movementMinutes != null && movementMinutes >= 10) {
      return 'You\'ve moved for $movementMinutes minutes today.';
    }
    final nextTime = context.nextScheduledTime;
    if (nextTime != null) return 'See you at $nextTime.';
    if (context.isFinalScheduledRecess) return 'That\'s all for today.';
    if (context.isManualSession) return 'That one was yours.';
    return 'Take that feeling with you.';
  }

  String _ordinal(int value) {
    final lastTwo = value % 100;
    if (lastTwo >= 11 && lastTwo <= 13) return '${value}th';
    return switch (value % 10) {
      1 => '${value}st',
      2 => '${value}nd',
      3 => '${value}rd',
      _ => '${value}th',
    };
  }
}
