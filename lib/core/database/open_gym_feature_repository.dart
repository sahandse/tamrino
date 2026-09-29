import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class OpenGymFeatureRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<void> setExerciseTracking({
    required int exerciseId,
    required String trackingType,
    String? mediaPath,
    String? mediaType,
    String? guideUrl,
  }) async {
    final db = await _db;
    final valid = {'strength', 'timed', 'cardio'};
    await db.update(
      'exercises',
      {
        'tracking_type': valid.contains(trackingType) ? trackingType : 'strength',
        'media_path': _emptyToNull(mediaPath),
        'media_type': _emptyToNull(mediaType),
        'guide_url': _emptyToNull(guideUrl),
      },
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  Future<List<Map<String, Object?>>> cardioExercises() async {
    final db = await _db;
    return db.query(
      'exercises',
      where: "tracking_type = 'cardio'",
      orderBy: 'is_favorite DESC, name COLLATE NOCASE ASC',
    );
  }

  Future<int> logCardioSession({
    required int exerciseId,
    required int durationSeconds,
    double? distanceKm,
    double? speedKmh,
    double? effort,
    String effortScale = 'rpe',
    DateTime? startedAt,
    String? notes,
  }) async {
    final db = await _db;
    final start = startedAt ?? DateTime.now();
    final finish = start.add(Duration(seconds: durationSeconds));
    return db.transaction((txn) async {
      final sessionId = await txn.insert('workout_sessions', {
        'plan_id': null,
        'started_at': start.toIso8601String(),
        'finished_at': finish.toIso8601String(),
        'notes': _emptyToNull(notes),
      });
      await txn.insert('workout_sets', {
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'set_number': 1,
        'duration_seconds': durationSeconds,
        'cardio_speed': speedKmh,
        'cardio_distance': distanceKm,
        'rpe': effort,
        'effort_scale': effortScale == 'rir' ? 'rir' : 'rpe',
        'completed': 1,
        'set_type': 'normal',
        'created_at': start.toIso8601String(),
      });
      return sessionId;
    });
  }

  Future<void> setSetEffortScale(int setId, String scale) async {
    final db = await _db;
    await db.update(
      'workout_sets',
      {'effort_scale': scale == 'rir' ? 'rir' : 'rpe'},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<int> addAttachment({
    required int sessionId,
    required String filePath,
    String? mediaType,
  }) async {
    final db = await _db;
    return db.insert('workout_attachments', {
      'session_id': sessionId,
      'file_path': filePath,
      'media_type': _emptyToNull(mediaType),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> attachmentsForSession(int sessionId) async {
    final db = await _db;
    return db.query(
      'workout_attachments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteAttachment(int attachmentId) async {
    final db = await _db;
    await db.delete('workout_attachments', where: 'id = ?', whereArgs: [attachmentId]);
  }

  Future<List<Map<String, Object?>>> relativeStrength() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT e.id AS exercise_id, e.name AS exercise_name,
        e.muscle_group,
        MAX(CASE
          WHEN ws.reps BETWEEN 1 AND 12 AND COALESCE(ws.weight,0) > 0
          THEN ws.weight * (1.0 + ws.reps / 30.0)
          ELSE 0 END) AS estimated_1rm
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      JOIN workout_sessions s ON s.id = ws.session_id
      WHERE s.finished_at IS NOT NULL
        AND ws.set_type != 'warmup'
        AND COALESCE(e.tracking_type, 'strength') = 'strength'
      GROUP BY e.id, e.name, e.muscle_group
      HAVING estimated_1rm > 0
      ORDER BY estimated_1rm DESC
    ''');
  }

  Future<List<Map<String, Object?>>> cardioHistory({int limit = 30}) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT ws.*, e.name AS exercise_name, s.started_at, s.finished_at
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      JOIN workout_sessions s ON s.id = ws.session_id
      WHERE e.tracking_type = 'cardio' AND s.finished_at IS NOT NULL
      ORDER BY s.started_at DESC LIMIT ?
    ''', [limit]);
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
