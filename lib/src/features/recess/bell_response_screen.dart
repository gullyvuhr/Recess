import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
                child: session.when(
                  data: (value) => value == null
                      ? _Unavailable(onDone: () => context.go('/home'))
                      : _Actions(session: value),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      _Unavailable(onDone: () => context.go('/home')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.session});

  final RecessSession session;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _acting = false;

  RecessSession get session => widget.session;

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _start() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await ref.read(recessActionsProvider).start(session.id);
      unawaited(HapticFeedback.lightImpact().catchError((_) {}));
      if (mounted) context.go('/recess/${session.id}');
    } catch (_) {
      if (mounted) _message('Recess could not start. Please try again.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _defer(RecessDeferralType type) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final result = await ref.read(recessActionsProvider).defer(
            session.id,
            type,
          );
      if (!mounted) return;
      if (!result.notificationSucceeded) {
        _message(
          'The reminder could not be scheduled. Check notification permissions.',
        );
      }
      context.go('/home');
    } catch (_) {
      if (mounted) {
        _message('Recess could not defer the Bells. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _rainCheck() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final result =
          await ref.read(recessActionsProvider).rainCheck(session.id);
      if (!mounted) return;
      if (!result.notificationSucceeded) {
        _message(
          'Rain check saved, but the next Bell could not be scheduled.',
        );
      }
      context.go('/home');
    } catch (_) {
      if (mounted) _message('Recess could not save the Rain check. Try again.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRespond = session.status == RecessSessionStatus.scheduled ||
        session.status == RecessSessionStatus.deferred;
    if (!canRespond) {
      return _Unavailable(onDone: () => context.go('/home'));
    }
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
          onPressed: _acting ? null : _start,
          child: const Padding(
            padding: EdgeInsets.all(13),
            child: Text('Start Recess'),
          ),
        ),
        if (session.canDefer) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed:
                _acting ? null : () => _defer(RecessDeferralType.fiveMinutes),
            child: const Text('Give me a minute'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed:
                _acting ? null : () => _defer(RecessDeferralType.afterThis),
            child: const Text('After this'),
          ),
        ],
        TextButton(
          onPressed: _acting ? null : _rainCheck,
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
