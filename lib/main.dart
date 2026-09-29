import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/database/app_database.dart';
import 'core/notifications/workout_reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'core/workout/workout_wakelock_monitor.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runZonedGuarded(
    () {
      runApp(const TamrinoApp());
      unawaited(_warmUpServices());
    },
    (error, stack) {
      debugPrint('Uncaught startup error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

Future<void> _warmUpServices() async {
  try {
    await AppDatabase.instance.database;
  } catch (error, stack) {
    debugPrint('Database warm-up failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  try {
    await WorkoutReminderService.instance.initialize();
  } catch (error, stack) {
    debugPrint('Notification warm-up failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}

class TamrinoApp extends StatelessWidget {
  const TamrinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تمرینو',
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const WorkoutWakeLockMonitor(child: HomeScreen()),
    );
  }
}
