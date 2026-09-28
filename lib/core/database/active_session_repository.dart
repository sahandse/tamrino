import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class ActiveSessionRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<Map<String, Object?>?> getActiveSession() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT ws.*, wp.name AS plan_name
      FROM workout_sessions ws
      LEFT JOIN workout_plans wp ON wp.id = ws.plan_id
      WHERE ws.finished_at IS NULL
      ORDER BY ws.started_at DESC
      LIMIT 1
    ''');
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getActiveSessionExercises() async {
    final active = await getActiveSession();
    if (active == null || active['plan_id'] == null) return const [];
    final db = await _db;
    return db.rawQuery('''
      SELECT pe.*, e.name, e.muscle_group, e.equipment, e.notes, e.is_favorite
      FROM plan_exercises pe
      JOIN exercises e ON e.id = pe.exercise_id
      WHERE pe.plan_id = ?
      ORDER BY pe.position ASC
    ''', [active['plan_id']]);
  }

  Future<void> cancelActiveSession(int sessionId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('workout_sets', where: 'session_id = ?', whereArgs: [sessionId]);
      await txn.delete('workout_sessions', where: 'id = ?', whereArgs: [sessionId]);
    });
  }

  Future<int> startOrReuseSession(int planId) async {
    final active = await getActiveSession();
    if (active != null) return active['id'] as int;
    final db = await _db;
    return db.insert('workout_sessions', {
      'plan_id': planId,
      'started_at': DateTime.now().toIso8601String(),
    });
  }
}
