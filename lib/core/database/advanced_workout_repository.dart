import 'dart:math' as math;

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
        )) ??
        0;
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
    List<double> availablePlates = const [25, 20, 15, 10, 5, 2.5, 1.25, .5],
  }) async {
    return calculatePlates(
      totalWeight: totalWeight,
      barWeight: barWeight,
      available: availablePlates,
    ).platesPerSide;
  }

  Future<void> ensureSessionExercises({
    required int sessionId,
    required int planId,
  }) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM session_exercises WHERE session_id = ?',
          [sessionId],
        )) ??
        0;
    if (count > 0) return;

    final rows = await db.query(
      'plan_exercises',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'position ASC',
    );
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('session_exercises', {
        'session_id': sessionId,
        'exercise_id': row['exercise_id'],
        'position': row['position'],
        'rest_seconds': row['rest_seconds'] ?? 90,
        'target_sets': row['target_sets'],
        'target_reps': row['target_reps'],
        'bar_weight': row['bar_weight'],
        'source_plan_exercise_id': row['id'],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> getSessionExercises(int sessionId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT se.*, e.name, e.muscle_group, e.equipment, e.notes,
        e.exercise_mode, e.is_bodyweight, e.per_side, e.is_favorite
      FROM session_exercises se
      JOIN exercises e ON e.id = se.exercise_id
      WHERE se.session_id = ?
      ORDER BY se.position ASC
    ''', [sessionId]);
  }

  Future<void> addExerciseToSession({
    required int sessionId,
    required int exerciseId,
    int targetSets = 3,
    String? targetReps,
    int restSeconds = 90,
    double? barWeight,
  }) async {
    final db = await _db;
    final maxPosition = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT MAX(position) FROM session_exercises WHERE session_id = ?',
          [sessionId],
        )) ??
        -1;
    await db.insert('session_exercises', {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'position': maxPosition + 1,
      'rest_seconds': restSeconds.clamp(0, 900),
      'target_sets': targetSets,
      'target_reps': targetReps,
      'bar_weight': barWeight,
    });
  }

  Future<void> removeExerciseFromSession({
    required int sessionExerciseId,
    required int sessionId,
    required int exerciseId,
    bool removeLoggedSets = false,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      if (removeLoggedSets) {
        await txn.delete(
          'workout_sets',
          where: 'session_id = ? AND exercise_id = ?',
          whereArgs: [sessionId, exerciseId],
        );
      }
      await txn.delete('session_exercises', where: 'id = ?', whereArgs: [sessionExerciseId]);
    });
  }

  Future<void> swapSessionExercise({
    required int sessionExerciseId,
    required int newExerciseId,
  }) async {
    final db = await _db;
    await db.update(
      'session_exercises',
      {'exercise_id': newExerciseId},
      where: 'id = ?',
      whereArgs: [sessionExerciseId],
    );
  }

  Future<void> setBarWeight(int sessionExerciseId, double? barWeight) async {
    final db = await _db;
    await db.update(
      'session_exercises',
      {'bar_weight': barWeight},
      where: 'id = ?',
      whereArgs: [sessionExerciseId],
    );
  }

  Future<void> setPlanLoadSettings({
    required int planId,
    required String strategy,
    required double step,
    required double recoveryReduction,
    required bool recoveryMode,
  }) async {
    const allowed = {'manual', 'linear', 'double', 'greyskull'};
    final db = await _db;
    await db.update(
      'workout_plans',
      {
        'load_strategy': allowed.contains(strategy) ? strategy : 'manual',
        'load_step': step.clamp(.25, 5.0),
        'recovery_reduction': recoveryReduction.clamp(5.0, 20.0),
        'recovery_mode': recoveryMode ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  Future<void> reschedulePlanForThisWeek({
    required int planId,
    required DateTime date,
  }) async {
    final db = await _db;
    final weekStart = _saturdayStart(date);
    await db.insert(
      'weekly_reschedules',
      {
        'plan_id': planId,
        'week_start': _dateOnly(weekStart),
        'scheduled_date': _dateOnly(date),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearRescheduleForThisWeek(int planId) async {
    final db = await _db;
    await db.delete(
      'weekly_reschedules',
      where: 'plan_id = ? AND week_start = ?',
      whereArgs: [planId, _dateOnly(_saturdayStart(DateTime.now()))],
    );
  }

  Future<List<Map<String, Object?>>> getPlansForDate(DateTime date) async {
    final db = await _db;
    final weekStart = _dateOnly(_saturdayStart(date));
    final dateOnly = _dateOnly(date);
    return db.rawQuery('''
      SELECT p.*, wr.scheduled_date
      FROM workout_plans p
      LEFT JOIN weekly_reschedules wr
        ON wr.plan_id = p.id AND wr.week_start = ?
      WHERE wr.scheduled_date = ?
         OR (wr.id IS NULL AND p.weekday = ?)
      ORDER BY p.created_at DESC
    ''', [weekStart, dateOnly, date.weekday]);
  }

  Future<LoadSuggestion?> getLoadSuggestion({
    required int exerciseId,
    required Map<String, Object?> plan,
    required String? targetReps,
  }) async {
    final strategy = plan['load_strategy'] as String? ?? 'manual';
    if (strategy == 'manual') return null;

    final db = await _db;
    final sessionRows = await db.rawQuery('''
      SELECT s.id
      FROM workout_sessions s
      JOIN workout_sets ws ON ws.session_id = s.id
      WHERE ws.exercise_id = ? AND s.finished_at IS NOT NULL
      ORDER BY s.finished_at DESC
      LIMIT 2
    ''', [exerciseId]);
    if (sessionRows.isEmpty) return null;

    final latestId = sessionRows.first['id'] as int;
    final latest = await db.query(
      'workout_sets',
      where: "session_id = ? AND exercise_id = ? AND set_type != 'warmup'",
      whereArgs: [latestId, exerciseId],
      orderBy: 'set_number ASC',
    );
    if (latest.isEmpty) return null;

    final weights = latest
        .map((e) => (e['weight'] as num?)?.toDouble())
        .whereType<double>()
        .where((v) => v > 0)
        .toList();
    if (weights.isEmpty) return null;

    final baseWeight = weights.reduce(math.max);
    final stepSetting = (plan['load_step'] as num?)?.toDouble() ?? 2.5;
    final conservativeStep = math.min(stepSetting, math.max(.5, baseWeight * .025));
    final recovery = plan['recovery_mode'] == 1;
    final reduction = ((plan['recovery_reduction'] as num?)?.toDouble() ?? 10).clamp(5, 20);

    if (recovery) {
      return LoadSuggestion(
        weight: _roundHalf(baseWeight * (1 - reduction / 100)),
        reason: 'حالت بازیابی فعال است؛ پیشنهاد سبک‌تر است.',
      );
    }

    final repRange = _parseRange(targetReps);
    final reps = latest.map((e) => (e['reps'] as num?)?.toInt()).whereType<int>().toList();
    final rpes = latest.map((e) => (e['rpe'] as num?)?.toDouble()).whereType<double>().toList();
    final comfortable = rpes.isEmpty || rpes.every((v) => v <= 8.0);

    if (strategy == 'double' && repRange != null) {
      final upper = repRange.$2;
      final completedUpper = reps.isNotEmpty && reps.every((v) => v >= upper);
      if (completedUpper && comfortable) {
        return LoadSuggestion(
          weight: _roundHalf(baseWeight + conservativeStep),
          reason: 'همه ست‌های قبلی به بالای بازه رسیدند؛ افزایش کوچک اختیاری است.',
        );
      }
      return LoadSuggestion(weight: baseWeight, reason: 'وزنه قبلی حفظ می‌شود تا بازه تکرار کامل شود.');
    }

    if (strategy == 'greyskull') {
      final lower = repRange?.$1 ?? 5;
      final metTarget = reps.isNotEmpty && reps.every((v) => v >= lower);
      if (metTarget && comfortable) {
        return LoadSuggestion(
          weight: _roundHalf(baseWeight + conservativeStep),
          reason: 'نسخه محافظه‌کارانه: فقط افزایش کوچک و اختیاری پیشنهاد می‌شود.',
        );
      }
      if (sessionRows.length >= 2) {
        final previous = await db.query(
          'workout_sets',
          where: "session_id = ? AND exercise_id = ? AND set_type != 'warmup'",
          whereArgs: [sessionRows[1]['id'], exerciseId],
        );
        final previousReps = previous.map((e) => (e['reps'] as num?)?.toInt()).whereType<int>().toList();
        final twoLowSessions = previousReps.isNotEmpty && previousReps.any((v) => v < lower) && reps.any((v) => v < lower);
        if (twoLowSessions) {
          return LoadSuggestion(
            weight: _roundHalf(baseWeight * .95),
            reason: 'دو جلسه زیر هدف ثبت شده؛ کاهش کوچک برای بازیابی پیشنهاد می‌شود.',
          );
        }
      }
      return LoadSuggestion(weight: baseWeight, reason: 'وزنه قبلی حفظ می‌شود.');
    }

    final lower = repRange?.$1;
    final metTarget = lower == null || (reps.isNotEmpty && reps.every((v) => v >= lower));
    if (metTarget && comfortable) {
      return LoadSuggestion(
        weight: _roundHalf(baseWeight + conservativeStep),
        reason: 'جلسه قبل با فشار کنترل‌شده ثبت شده؛ افزایش کوچک اختیاری است.',
      );
    }
    return LoadSuggestion(weight: baseWeight, reason: 'وزنه قبلی حفظ می‌شود.');
  }

  PlateResult calculatePlates({
    required double totalWeight,
    required double barWeight,
    List<double> available = const [25, 20, 15, 10, 5, 2.5, 1.25, .5],
  }) {
    if (totalWeight <= barWeight || barWeight <= 0) {
      return PlateResult(const [], math.max(0, totalWeight - barWeight));
    }
    var perSide = (totalWeight - barWeight) / 2;
    final plates = <double>[];
    for (final plate in available) {
      while (perSide + .001 >= plate) {
        plates.add(plate);
        perSide -= plate;
      }
    }
    return PlateResult(plates, perSide * 2);
  }

  DateTime _saturdayStart(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final delta = (clean.weekday - DateTime.saturday + 7) % 7;
    return clean.subtract(Duration(days: delta));
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  (int, int)? _parseRange(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll('–', '-').replaceAll('—', '-');
    final parts = normalized.split('-').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
    if (parts.length >= 2) return (parts[0], parts[1]);
    if (parts.length == 1) return (parts[0], parts[0]);
    return null;
  }

  double _roundHalf(double value) => (value * 2).round() / 2;

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}

class LoadSuggestion {
  const LoadSuggestion({required this.weight, required this.reason});
  final double weight;
  final String reason;
}

class PlateResult {
  const PlateResult(this.platesPerSide, this.remainder);
  final List<double> platesPerSide;
  final double remainder;
  bool get exact => remainder.abs() < .01;
}
