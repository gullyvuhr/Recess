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

  Future<void> _complete() async {
    await ref.read(recessActionsProvider).complete(widget.sessionId);
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wb_sunny_outlined, size: 82),
                const SizedBox(height: 24),
                Text(
                  'You made some room.',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'That counts. Come back whenever the next good moment appears.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to today'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final session = ref.watch(sessionProvider(widget.sessionId));
    return session.when(
      data: (value) => value?.status == RecessSessionStatus.active
          ? _ActiveSession(session: value!, onComplete: _complete)
          : const _InvalidSession(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _InvalidSession(),
    );
  }
}

class _ActiveSession extends ConsumerWidget {
  const _ActiveSession({required this.session, required this.onComplete});

  final RecessSession session;
  final Future<void> Function() onComplete;

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
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.close),
                ),
                backgroundColor: Colors.transparent,
              ),
              body: SafeArea(
                child: Padding(
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
                        onPressed: onComplete,
                        child: const Padding(
                          padding: EdgeInsets.all(13),
                          child: Text("I'm back"),
                        ),
                      ),
                    ],
                  ),
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
