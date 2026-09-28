import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class WorkoutRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Map<String, Object?>>> getExercises() async {
    final db = await _db;
    return db.query('exercises', orderBy: 'name COLLATE NOCASE ASC');
  }

  Future<int> addExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
    String? notes,
  }) async {
    final db = await _db;
    return db.insert('exercises', {
      'name': name.trim(),
      'muscle_group': _emptyToNull(muscleGroup),
      'equipment': _emptyToNull(equipment),
      'notes': _emptyToNull(notes),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getPlans() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT p.*, COUNT(pe.id) AS exercise_count
      FROM workout_plans p
      LEFT JOIN plan_exercises pe ON pe.plan_id = p.id
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''');
  }

  Future<int> createPlan({required String name, String? notes}) async {
    final db = await _db;
    return db.insert('workout_plans', {
      'name': name.trim(),
      'notes': _emptyToNull(notes),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> addExerciseToPlan({
    required int planId,
    required int exerciseId,
    int? targetSets,
    String? targetReps,
    int restSeconds = 90,
  }) async {
    final db = await _db;
    final maxPosition = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT MAX(position) FROM plan_exercises WHERE plan_id = ?',
          [planId],
        )) ??
        -1;

    await db.insert('plan_exercises', {
      'plan_id': planId,
      'exercise_id': exerciseId,
      'position': maxPosition + 1,
      'target_sets': targetSets,
      'target_reps': _emptyToNull(targetReps),
      'rest_seconds': restSeconds.clamp(0, 900),
    });
  }

  Future<void> updateExerciseRestSeconds({
    required int planExerciseId,
    required int restSeconds,
  }) async {
    final db = await _db;
    await db.update(
      'plan_exercises',
      {'rest_seconds': restSeconds.clamp(0, 900)},
      where: 'id = ?',
      whereArgs: [planExerciseId],
    );
  }

  Future<List<Map<String, Object?>>> getPlanExercises(int planId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT pe.*, e.name, e.muscle_group, e.equipment
      FROM plan_exercises pe
      JOIN exercises e ON e.id = pe.exercise_id
      WHERE pe.plan_id = ?
      ORDER BY pe.position ASC
    ''', [planId]);
  }

  Future<int> startSession(int planId) async {
    final db = await _db;
    return db.insert('workout_sessions', {
      'plan_id': planId,
      'started_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> addSet({
    required int sessionId,
    required int exerciseId,
    required int setNumber,
    int? reps,
    double? weight,
    double? rpe,
    String setType = 'normal',
    String? supersetGroup,
  }) async {
    final db = await _db;
    return db.insert('workout_sets', {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'reps': reps,
      'weight': weight,
      'rpe': rpe,
      'completed': 1,
      'set_type': _validSetType(setType),
      'superset_group': _emptyToNull(supersetGroup),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateSet({
    required int setId,
    int? reps,
    double? weight,
    double? rpe,
    String? setType,
    String? supersetGroup,
  }) async {
    final db = await _db;
    await db.update(
      'workout_sets',
      {
        'reps': reps,
        'weight': weight,
        'rpe': rpe,
        if (setType != null) 'set_type': _validSetType(setType),
        'superset_group': _emptyToNull(supersetGroup),
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<void> deleteSet(int setId) async {
    final db = await _db;
    await db.delete('workout_sets', where: 'id = ?', whereArgs: [setId]);
  }

  Future<List<Map<String, Object?>>> getSessionSets(int sessionId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT ws.*, e.name AS exercise_name
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      WHERE ws.session_id = ?
      ORDER BY ws.exercise_id ASC, ws.set_number ASC
    ''', [sessionId]);
  }

  Future<void> finishSession(int sessionId) async {
    final db = await _db;
    await db.update(
      'workout_sessions',
      {'finished_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<Map<String, Object?>>> getRecentSessions({int limit = 30}) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT ws.*, wp.name AS plan_name,
        COUNT(s.id) AS set_count,
        COALESCE(SUM(COALESCE(s.weight, 0) * COALESCE(s.reps, 0)), 0) AS volume
      FROM workout_sessions ws
      LEFT JOIN workout_plans wp ON wp.id = ws.plan_id
      LEFT JOIN workout_sets s ON s.session_id = ws.id
      WHERE ws.finished_at IS NOT NULL
      GROUP BY ws.id
      ORDER BY ws.started_at DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, Object?>>> getActivityDays({int days = 84}) async {
    final db = await _db;
    final from = DateTime.now().subtract(Duration(days: days - 1));
    return db.rawQuery('''
      SELECT substr(started_at, 1, 10) AS day,
        COUNT(*) AS workout_count
      FROM workout_sessions
      WHERE finished_at IS NOT NULL AND started_at >= ?
      GROUP BY substr(started_at, 1, 10)
      ORDER BY day ASC
    ''', [from.toIso8601String()]);
  }

  Future<Map<String, Object?>> getProgressSummary() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT ws.id) AS workout_count,
        COUNT(s.id) AS set_count,
        COALESCE(SUM(COALESCE(s.weight, 0) * COALESCE(s.reps, 0)), 0) AS total_volume
      FROM workout_sessions ws
      LEFT JOIN workout_sets s ON s.session_id = ws.id
      WHERE ws.finished_at IS NOT NULL
    ''');
    return rows.first;
  }

  Future<List<Map<String, Object?>>> getPersonalRecords({int limit = 20}) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT e.id AS exercise_id, e.name AS exercise_name,
        MAX(COALESCE(ws.weight, 0)) AS max_weight,
        MAX(
          CASE
            WHEN COALESCE(ws.weight, 0) > 0 AND COALESCE(ws.reps, 0) > 0
            THEN ws.weight * (1.0 + ws.reps / 30.0)
            ELSE 0
          END
        ) AS estimated_1rm
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      JOIN workout_sessions session ON session.id = ws.session_id
      WHERE session.finished_at IS NOT NULL
        AND ws.set_type != 'warmup'
      GROUP BY e.id, e.name
      HAVING MAX(COALESCE(ws.weight, 0)) > 0
      ORDER BY estimated_1rm DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, Object?>>> getVolumeTrend({int limit = 8}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT ws.id, ws.started_at, wp.name AS plan_name,
        COALESCE(SUM(COALESCE(s.weight, 0) * COALESCE(s.reps, 0)), 0) AS volume
      FROM workout_sessions ws
      LEFT JOIN workout_plans wp ON wp.id = ws.plan_id
      LEFT JOIN workout_sets s ON s.session_id = ws.id
      WHERE ws.finished_at IS NOT NULL
      GROUP BY ws.id
      ORDER BY ws.started_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.reversed.toList();
  }

  String _validSetType(String value) {
    const allowed = {'normal', 'warmup', 'drop', 'failure', 'rest_pause'};
    return allowed.contains(value) ? value : 'normal';
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
