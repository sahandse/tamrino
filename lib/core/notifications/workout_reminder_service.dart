import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class WorkoutReminderService {
  WorkoutReminderService._();
  static final WorkoutReminderService instance = WorkoutReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Timezone is optional during startup. Scheduling can still use tz.local.
    }

    const android = AndroidInitializationSettings('@drawable/tamrino_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    _ready = true;
  }

  Future<void> _requestPermissionIfNeeded() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> scheduleWeekly({
    required int planId,
    required String planName,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    await initialize();
    await _requestPermissionIfNeeded();

    final next = _nextWeekdayTime(weekday, hour, minute);

    await _plugin.zonedSchedule(
      10000 + planId,
      'زمان تمرین رسیده 💪',
      planName,
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_reminders',
          'یادآوری تمرین',
          channelDescription: 'یادآوری برنامه‌های هفتگی تمرینو',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'plan:$planId',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled_$planId', true);
    await prefs.setInt('reminder_hour_$planId', hour);
    await prefs.setInt('reminder_minute_$planId', minute);
  }

  Future<void> cancel(int planId) async {
    await initialize();
    await _plugin.cancel(10000 + planId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled_$planId', false);
  }

  Future<WorkoutReminderPreference> preferenceFor(int planId) async {
    final prefs = await SharedPreferences.getInstance();
    return WorkoutReminderPreference(
      enabled: prefs.getBool('reminder_enabled_$planId') ?? false,
      hour: prefs.getInt('reminder_hour_$planId') ?? 18,
      minute: prefs.getInt('reminder_minute_$planId') ?? 0,
    );
  }

  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    var days = (weekday - candidate.weekday) % 7;
    if (days == 0 && !candidate.isAfter(now)) days = 7;
    candidate = candidate.add(Duration(days: days));
    return candidate;
  }
}

class WorkoutReminderPreference {
  const WorkoutReminderPreference({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
}
