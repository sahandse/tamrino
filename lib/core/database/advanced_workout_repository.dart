import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class AdvancedWorkoutRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<Map<String, Object?>> createFreestylePlan(List<int> exerciseIds) async {
    if (exerciseIds.isEmpty) throw StateError('حداقل یک حرکت انتخاب کن.');
    final db = await _db;
    return db.transaction((txn) async {
      final planId = await txn.insert('workout_plans', {
        'name': 'تمرین آزاد',
        'notes': '__tamrino_freestyle__',
        'weekday': null,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var i = 0; i < exerciseIds.length; i++) {
        await txn.insert('plan_exercises', {
          'plan_id': planId,
          'exercise_id': exerciseIds[i],
          'position': i,
          'target_sets': 3,
          'target_reps': 'آزاد',
          'rest_seconds': 90,
        });
      }
      return {'id': planId, 'name': 'تمرین آزاد', 'notes': '__tamrino_freestyle__'};
    });
  }

  Future<void> cleanupFreestylePlan(int planId) async {
    final db = await _db;
    final active = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM workout_sessions WHERE plan_id = ? AND finished_at IS NULL',
      [planId],
    )) ?? 0;
    if (active == 0) {
      await db.delete(
        'workout_plans',
        where: "id = ? AND notes = '__tamrino_freestyle__'",
        whereArgs: [planId],
      );
    }
  }

  Future<int> createPastSession({
    required DateTime startedAt,
    required Duration duration,
    int? planId,
    String? notes,
  }) async {
    final db = await _db;
    final finishedAt = startedAt.add(duration);
    return db.insert('workout_sessions', {
      'plan_id': planId,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt.toIso8601String(),
      'notes': _emptyToNull(notes),
    });
  }

  Future<void> addPastSet({
    required int sessionId,
    required int exerciseId,
    required int setNumber,
    int? reps,
    double? weight,
    int? durationSeconds,
    double? rpe,
  }) async {
    final db = await _db;
    await db.insert('workout_sets', {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'reps': reps,
      'weight': weight,
      'duration_seconds': durationSeconds,
      'rpe': rpe,
      'completed': 1,
      'set_type': 'normal',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateSessionTime({
    required int sessionId,
    required DateTime startedAt,
    required Duration duration,
  }) async {
    final db = await _db;
    await db.update(
      'workout_sessions',
      {
        'started_at': startedAt.toIso8601String(),
        'finished_at': startedAt.add(duration).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<double>> plateBreakdown({
    required double totalWeight,
    double barWeight = 20,
    List<double> availablePlates = const [25, 20, 15, 10, 5, 2.5, 1.25],
  }) async {
    final perSide = (totalWeight - barWeight) / 2;
    if (perSide <= 0) return const [];
    var remaining = perSide;
    final result = <double>[];
    for (final plate in availablePlates) {
      while (remaining + 0.0001 >= plate) {
        result.add(plate);
        remaining -= plate;
      }
    }
    return result;
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
