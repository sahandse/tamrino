import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class ExerciseHistoryRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<Map<String, Object?>?> exercise(int exerciseId) async {
    final db = await _db;
    final rows = await db.query('exercises', where: 'id = ?', whereArgs: [exerciseId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> sessions(int exerciseId, {int limit = 20}) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT s.id AS session_id, s.started_at, s.finished_at,
        p.name AS plan_name,
        COUNT(ws.id) AS set_count,
        MAX(CASE
          WHEN ws.set_type != 'warmup' AND ws.reps BETWEEN 1 AND 12 AND COALESCE(ws.weight,0) > 0
          THEN ws.weight * (1.0 + ws.reps / 30.0)
          ELSE 0 END) AS estimated_1rm,
        MAX(COALESCE(ws.weight,0)) AS max_weight,
        SUM(COALESCE(ws.duration_seconds,0)) AS timed_seconds,
        MAX(COALESCE(ws.cardio_distance,0)) AS distance_km
      FROM workout_sessions s
      JOIN workout_sets ws ON ws.session_id = s.id
      LEFT JOIN workout_plans p ON p.id = s.plan_id
      WHERE ws.exercise_id = ? AND s.finished_at IS NOT NULL
      GROUP BY s.id
      ORDER BY s.started_at DESC
      LIMIT ?
    ''', [exerciseId, limit]);
  }

  Future<List<Map<String, Object?>>> setsForSession(int sessionId, int exerciseId) async {
    final db = await _db;
    return db.query(
      'workout_sets',
      where: 'session_id = ? AND exercise_id = ?',
      whereArgs: [sessionId, exerciseId],
      orderBy: 'set_number ASC',
    );
  }
}
