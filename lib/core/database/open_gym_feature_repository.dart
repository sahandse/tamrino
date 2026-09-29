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

  Future<String> sessionAsText(int sessionId) async {
    final db = await _db;
    final sessions = await db.rawQuery('''
      SELECT s.*, p.name AS plan_name
      FROM workout_sessions s
      LEFT JOIN workout_plans p ON p.id = s.plan_id
      WHERE s.id = ? LIMIT 1
    ''', [sessionId]);
    if (sessions.isEmpty) throw StateError('جلسه پیدا نشد.');

    final sets = await db.rawQuery('''
      SELECT ws.*, e.name AS exercise_name, e.tracking_type
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      WHERE ws.session_id = ?
      ORDER BY ws.created_at ASC, ws.set_number ASC
    ''', [sessionId]);

    final session = sessions.first;
    final start = DateTime.tryParse(session['started_at'] as String? ?? '');
    final buffer = StringBuffer();
    buffer.writeln(session['plan_name'] as String? ?? 'تمرین آزاد');
    if (start != null) {
      buffer.writeln('${start.year}/${start.month}/${start.day} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}');
    }
    if ((session['notes'] as String?)?.isNotEmpty == true) {
      buffer.writeln('یادداشت: ${session['notes']}');
    }

    String? current;
    for (final set in sets) {
      final name = set['exercise_name'] as String? ?? 'حرکت';
      if (name != current) {
        current = name;
        buffer.writeln('\n$name');
      }
      final duration = (set['duration_seconds'] as num?)?.toInt();
      final distance = (set['cardio_distance'] as num?)?.toDouble();
      final speed = (set['cardio_speed'] as num?)?.toDouble();
      final reps = (set['reps'] as num?)?.toInt();
      final weight = (set['weight'] as num?)?.toDouble();
      final effort = (set['rpe'] as num?)?.toDouble();
      final scale = (set['effort_scale'] as String? ?? 'rpe').toUpperCase();
      final parts = <String>[];
      if (reps != null) parts.add('$reps تکرار');
      if (weight != null) parts.add('${_number(weight)} kg');
      if (duration != null) parts.add('$duration ثانیه');
      if (distance != null) parts.add('${_number(distance)} km');
      if (speed != null) parts.add('${_number(speed)} km/h');
      if (effort != null) parts.add('$scale ${_number(effort)}');
      buffer.writeln('• ${parts.isEmpty ? 'ثبت شد' : parts.join(' • ')}');
    }
    return buffer.toString().trim();
  }

  Future<int> saveSessionAsRoutine({
    required int sessionId,
    required String name,
    int? weekday,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT ws.exercise_id, e.name,
        COUNT(ws.id) AS set_count,
        MIN(ws.reps) AS min_reps,
        MAX(ws.reps) AS max_reps,
        MIN(ws.created_at) AS first_set
      FROM workout_sets ws
      JOIN exercises e ON e.id = ws.exercise_id
      WHERE ws.session_id = ?
      GROUP BY ws.exercise_id, e.name
      ORDER BY first_set ASC
    ''', [sessionId]);
    if (rows.isEmpty) throw StateError('این جلسه ستی برای تبدیل به برنامه ندارد.');

    return db.transaction((txn) async {
      final planId = await txn.insert('workout_plans', {
        'name': name.trim().isEmpty ? 'برنامه از تاریخچه' : name.trim(),
        'notes': 'ساخته‌شده از یک جلسه ذخیره‌شده',
        'weekday': weekday,
        'load_strategy': 'manual',
        'load_step': 2.5,
        'recovery_reduction': 10,
        'recovery_mode': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final minReps = (row['min_reps'] as num?)?.toInt();
        final maxReps = (row['max_reps'] as num?)?.toInt();
        final targetReps = minReps == null
            ? null
            : minReps == maxReps
                ? '$minReps'
                : '$minReps-$maxReps';
        await txn.insert('plan_exercises', {
          'plan_id': planId,
          'exercise_id': row['exercise_id'],
          'position': i,
          'target_sets': (row['set_count'] as num?)?.toInt(),
          'target_reps': targetReps,
          'rest_seconds': 90,
        });
      }
      return planId;
    });
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

  String _number(double value) => value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
