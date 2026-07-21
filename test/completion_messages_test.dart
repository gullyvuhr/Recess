import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/completion_messages.dart';

void main() {
  const formatter = CompletionMessageFormatter();

  test('primary messages rotate deterministically', () {
    final messages = List.generate(
      CompletionMessageFormatter.primaryMessages.length,
      (seed) => formatter
          .format(CompletionMessageContext(selectionSeed: seed))
          .primary,
    );

    expect(
        messages.toSet(), CompletionMessageFormatter.primaryMessages.toSet());
  });

  test('previous primary message is not immediately repeated', () {
    final first = formatter.format(
      const CompletionMessageContext(selectionSeed: 2),
    );
    final next = formatter.format(
      CompletionMessageContext(
        selectionSeed: 2,
        previousPrimary: first.primary,
      ),
    );

    expect(next.primary, isNot(first.primary));
  });

  test('reliable completion fact takes priority', () {
    final message = formatter.format(
      const CompletionMessageContext(
        selectionSeed: 0,
        completedCountToday: 3,
        movementMinutesToday: 18,
        nextScheduledTime: '11:00 AM',
        isFinalScheduledRecess: true,
        isManualSession: true,
      ),
    );

    expect(message.supporting, 'That\'s your 3rd Recess today.');
  });

  test('movement fact is used when it is meaningful', () {
    final message = formatter.format(
      const CompletionMessageContext(
        selectionSeed: 0,
        completedCountToday: 1,
        movementMinutesToday: 18,
        nextScheduledTime: '11:00 AM',
      ),
    );

    expect(message.supporting, 'You\'ve moved for 18 minutes today.');
  });

  test('next scheduled Recess follows contextual facts', () {
    final message = formatter.format(
      const CompletionMessageContext(
        selectionSeed: 0,
        completedCountToday: 1,
        movementMinutesToday: 5,
        nextScheduledTime: '11:00 AM',
      ),
    );

    expect(message.supporting, 'See you at 11:00 AM.');
  });

  test('final scheduled Recess is acknowledged', () {
    final message = formatter.format(
      const CompletionMessageContext(
        selectionSeed: 0,
        isFinalScheduledRecess: true,
      ),
    );

    expect(message.supporting, 'That\'s all for today.');
  });

  test('manual session is acknowledged', () {
    final message = formatter.format(
      const CompletionMessageContext(
        selectionSeed: 0,
        isManualSession: true,
      ),
    );

    expect(message.supporting, 'That one was yours.');
  });

  test('quiet fallback is available without context', () {
    final message = formatter.format(
      const CompletionMessageContext(selectionSeed: 0),
    );

    expect(message.supporting, 'Take that feeling with you.');
  });
}
