import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await RecessDatabase.open();
  final notifications = NotificationService();
  await notifications.initialize();
  final schedule = await database.schedule();
  if (schedule != null) {
    try {
      await notifications.scheduleBell(schedule);
    } catch (_) {
      // A denied notification permission must not prevent the app from opening.
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const RecessApp(),
    ),
  );
}
