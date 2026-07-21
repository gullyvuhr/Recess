import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

class RecessScreen extends ConsumerStatefulWidget {
  const RecessScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  ConsumerState<RecessScreen> createState() => _RecessScreenState();
}

class _RecessScreenState extends ConsumerState<RecessScreen> {
  bool _done = false;
  bool _completing = false;
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
      setState(() => _done = true);
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
      return const _CompletionTransition();
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

class _CompletionTransition extends ConsumerWidget {
  const _CompletionTransition();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(homeRecessStatusProvider).valueOrNull;
    final next = status?.scheduledAt;
    return Scaffold(
      body: _ScrollableBody(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 52),
            const SizedBox(height: 20),
            Text(
              'Nice work.',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              next == null
                  ? 'See you next time.'
                  : 'See you at ${TimeOfDay.fromDateTime(next).format(context)}.',
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
                      value.instruction,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'About ${value.durationMinutes} ${value.durationMinutes == 1 ? 'minute' : 'minutes'}',
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
