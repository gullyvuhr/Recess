import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/completion_messages.dart';
import '../../core/insights.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../exercises/exercise_prescription_service.dart';

class RecessScreen extends ConsumerStatefulWidget {
  const RecessScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  ConsumerState<RecessScreen> createState() => _RecessScreenState();
}

class _RecessScreenState extends ConsumerState<RecessScreen> {
  bool _done = false;
  bool _completing = false;
  CompletionMessageContext? _completionContext;
  Timer? _returnTimer;

  @override
  void dispose() {
    _returnTimer?.cancel();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      final result =
          await ref.read(recessActionsProvider).complete(widget.sessionId);
      if (!mounted) return;
      if (!result.notificationSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recess was completed, but the next Bell could not be scheduled.',
            ),
          ),
        );
      }
      HomeRecessStatus? homeStatus;
      try {
        homeStatus = await ref.read(homeRecessStatusProvider.future);
      } catch (_) {}
      TodayInsightMetrics? today;
      try {
        today = (await ref.read(insightProvider.future)).today;
      } catch (_) {}
      if (!mounted) return;
      final completed = result.value;
      final isManual = completed.originalScheduledAt == completed.createdAt;
      final next = homeStatus?.scheduledAt;
      setState(() {
        _completionContext = CompletionMessageContext(
          selectionSeed: completed.id,
          completedCountToday: today?.completed,
          movementMinutesToday: today?.completedMovementDuration.inMinutes,
          nextScheduledTime: next == null
              ? null
              : TimeOfDay.fromDateTime(next).format(context),
          isFinalScheduledRecess: next == null && !isManual,
          isManualSession: isManual,
        );
        _done = true;
      });
      _returnTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) context.go('/home');
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recess could not be completed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _CompletionTransition(messageContext: _completionContext!);
    }
    final session = ref.watch(sessionProvider(widget.sessionId));
    return session.when(
      data: (value) => value?.status == RecessSessionStatus.active
          ? _ActiveSession(
              session: value!,
              onComplete: _complete,
              isCompleting: _completing,
            )
          : const _InvalidSession(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _InvalidSession(),
    );
  }
}

class _CompletionTransition extends StatelessWidget {
  const _CompletionTransition({required this.messageContext});

  final CompletionMessageContext messageContext;

  @override
  Widget build(BuildContext context) {
    final message = const CompletionMessageFormatter().format(messageContext);
    return Scaffold(
      body: _ScrollableBody(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 28),
            Text(
              message.primary,
              key: const Key('completion-primary'),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              message.supporting,
              key: const Key('completion-supporting'),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSession extends ConsumerWidget {
  const _ActiveSession({
    required this.session,
    required this.onComplete,
    required this.isCompleting,
  });

  final RecessSession session;
  final Future<void> Function() onComplete;
  final bool isCompleting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseId = session.exerciseId;
    if (exerciseId == null) return const _InvalidSession();
    final exercise = ref.watch(exerciseProvider(exerciseId));
    final duration =
        ref.watch(preferencesProvider).valueOrNull?.durationMinutes ?? 5;
    return exercise.when(
      data: (value) => value == null
          ? const _InvalidSession()
          : Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  onPressed: isCompleting ? null : () => context.go('/home'),
                  icon: const Icon(Icons.close),
                ),
                backgroundColor: Colors.transparent,
              ),
              body: _ScrollableBody(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Text(
                      value.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value.description,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      const ExercisePrescriptionService()
                          .generate(value, duration),
                      style: Theme.of(context).textTheme.labelLarge,
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: isCompleting ? null : onComplete,
                      child: const Padding(
                        padding: EdgeInsets.all(13),
                        child: Text("I'm back"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _InvalidSession(),
    );
  }
}

class _ScrollableBody extends StatelessWidget {
  const _ScrollableBody({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - padding.vertical,
              ),
              child: IntrinsicHeight(child: child),
            ),
          ),
        ),
      );
}

class _InvalidSession extends StatelessWidget {
  const _InvalidSession();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Back to today'),
          ),
        ),
      );
}
