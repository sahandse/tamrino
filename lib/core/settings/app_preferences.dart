import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class AppPreferences {
  AppPreferences._();
  static final AppPreferences instance = AppPreferences._();

  static const _weekStartKey = 'week_start';
  static const _effortScaleKey = 'effort_scale';
  static const _keepAwakeKey = 'keep_awake_during_workout';
  static const _timerFlashKey = 'timer_flash';
  static const _exerciseMediaKey = 'exercise_media_mode';
  static const _platesKey = 'owned_plates_kg';

  Future<int> weekStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_weekStartKey) ?? DateTime.saturday;
  }

  Future<void> setWeekStart(int weekday) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weekStartKey, weekday.clamp(1, 7));
  }

  Future<String> effortScale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_effortScaleKey) == 'rir' ? 'rir' : 'rpe';
    await _syncEffortScaleToDatabase(value);
    return value;
  }

  Future<void> setEffortScale(String value) async {
    final normalized = value == 'rir' ? 'rir' : 'rpe';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_effortScaleKey, normalized);
    await _syncEffortScaleToDatabase(normalized);
  }

  Future<void> _syncEffortScaleToDatabase(String value) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'app_settings',
        {'setting_key': 'effort_scale', 'setting_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Preference must remain usable even if the database is unavailable.
    }
  }

  Future<bool> keepAwakeDuringWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepAwakeKey) ?? true;
  }

  Future<void> setKeepAwakeDuringWorkout(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepAwakeKey, value);
  }

  Future<bool> timerFlash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_timerFlashKey) ?? false;
  }

  Future<void> setTimerFlash(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timerFlashKey, value);
  }

  Future<String> exerciseMediaMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_exerciseMediaKey) ?? 'small';
  }

  Future<void> setExerciseMediaMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = {'full', 'small', 'hidden'};
    await prefs.setString(_exerciseMediaKey, valid.contains(value) ? value : 'small');
  }

  Future<List<double>> ownedPlatesKg() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_platesKey);
    if (raw == null || raw.isEmpty) {
      return const [25, 20, 15, 10, 5, 2.5, 1.25];
    }
    final values = raw.map(double.tryParse).whereType<double>().where((e) => e > 0).toSet().toList();
    values.sort((a, b) => b.compareTo(a));
    return values;
  }

  Future<void> setOwnedPlatesKg(List<double> values) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = values.where((e) => e > 0).toSet().toList()..sort((a, b) => b.compareTo(a));
    await prefs.setStringList(_platesKey, cleaned.map((e) => e.toString()).toList());
  }
}
