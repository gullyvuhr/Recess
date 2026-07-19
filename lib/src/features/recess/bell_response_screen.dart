import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

class BellResponseScreen extends ConsumerWidget {
  const BellResponseScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId));
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: session.when(
            data: (value) => value == null
                ? _Unavailable(onDone: () => context.go('/home'))
                : _Actions(session: value),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _Unavailable(onDone: () => context.go('/home')),
          ),
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.session});

  final RecessSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRespond = session.status == RecessSessionStatus.scheduled ||
        session.status == RecessSessionStatus.deferred;
    if (!canRespond) {
      return _Unavailable(onDone: () => context.go('/home'));
    }
    final actions = ref.read(recessActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(
          Icons.notifications_active_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          session.canDefer ? 'Bells.' : 'The Bells are back.',
          style: Theme.of(context).textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'What feels right for this moment?',
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton(
          onPressed: () async {
            await actions.start(session.id);
            if (context.mounted) context.go('/recess/${session.id}');
          },
          child: const Padding(
            padding: EdgeInsets.all(13),
            child: Text('Start Recess'),
          ),
        ),
        if (session.canDefer) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              await actions.defer(
                session.id,
                RecessDeferralType.fiveMinutes,
              );
              if (context.mounted) context.go('/home');
            },
            child: const Text('Give me a minute'),
          ),
          OutlinedButton(
            onPressed: () async {
              await actions.defer(
                session.id,
                RecessDeferralType.afterThis,
              );
              if (context.mounted) context.go('/home');
            },
            child: const Text('After this'),
          ),
        ],
        TextButton(
          onPressed: () async {
            await actions.rainCheck(session.id);
            if (context.mounted) context.go('/home');
          },
          child: const Text('Rain check'),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton(
          onPressed: onDone,
          child: const Text('Back to today'),
        ),
      );
}
