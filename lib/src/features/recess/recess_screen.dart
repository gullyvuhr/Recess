import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class RecessScreen extends ConsumerStatefulWidget {
  const RecessScreen({super.key});

  @override
  ConsumerState<RecessScreen> createState() => _RecessScreenState();
}

class _RecessScreenState extends ConsumerState<RecessScreen> {
  bool _done = false;

  Future<void> _schedule(Duration delay, String message) async {
    await ref.read(notificationServiceProvider).remindIn(delay, label: message);
    if (mounted) context.go('/home');
  }

  Future<void> _afterThis() async {
    final controller = TextEditingController(text: '15');
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('After this'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutes from now')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text)),
              child: const Text('Set reminder')),
        ],
      ),
    );
    if (minutes != null && minutes > 0) {
      await _schedule(
          Duration(minutes: minutes), 'The thing is done. Take your recess.');
    }
  }

  Future<void> _complete() async {
    await ref.read(recessActionsProvider).complete();
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wb_sunny_outlined, size: 82),
              const SizedBox(height: 24),
              Text('You made some room.',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                  'That counts. Come back whenever the next good moment appears.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to today')),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.close)),
          backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Text('Recess starts here.',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
                'Step away, stretch, look outside, or do absolutely nothing.',
                textAlign: TextAlign.center),
            const Spacer(),
            FilledButton(
                onPressed: _complete,
                child: const Padding(
                    padding: EdgeInsets.all(13), child: Text("I'm back"))),
            const SizedBox(height: 10),
            OutlinedButton(
                onPressed: () => _schedule(const Duration(minutes: 1),
                    'A minute has passed. Ready for recess?'),
                child: const Text('Give me a minute')),
            OutlinedButton(
                onPressed: _afterThis, child: const Text('After this')),
            TextButton(
              onPressed: () async {
                await ref.read(recessActionsProvider).rainCheck();
                if (context.mounted) context.go('/home');
              },
              child: const Text('Rain check'),
            ),
          ]),
        ),
      ),
    );
  }
}
