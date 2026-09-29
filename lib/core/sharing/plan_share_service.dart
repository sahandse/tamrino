import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class PlanShareService {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<String?> exportPlan(int planId) async {
    final db = await _db;
    final plans = await db.query('workout_plans', where: 'id = ?', whereArgs: [planId], limit: 1);
    if (plans.isEmpty) throw StateError('برنامه پیدا نشد.');

    final exercises = await db.rawQuery('''
      SELECT pe.position, pe.target_sets, pe.target_reps, pe.rest_seconds,
        pe.bar_weight, pe.strategy_override,
        e.name, e.muscle_group, e.equipment, e.notes, e.exercise_mode,
        e.tracking_type, e.is_bodyweight, e.per_side, e.guide_url
      FROM plan_exercises pe
      JOIN exercises e ON e.id = pe.exercise_id
      WHERE pe.plan_id = ?
      ORDER BY pe.position ASC
    ''', [planId]);

    final payload = {
      'format': 'tamrino-plan',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'plan': {
        'name': plans.first['name'],
        'notes': plans.first['notes'],
        'weekday': plans.first['weekday'],
        'load_strategy': plans.first['load_strategy'],
        'load_step': plans.first['load_step'],
        'recovery_reduction': plans.first['recovery_reduction'],
        'recovery_mode': plans.first['recovery_mode'],
      },
      'exercises': exercises,
    };

    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره برنامه تمرینو',
      fileName: 'tamrino-plan-$planId.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    return path;
  }

  Future<int?> importPlan() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.single;
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw StateError('فایل قابل خواندن نیست.');

    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'tamrino-plan') {
      throw const FormatException('فایل برنامه تمرینو معتبر نیست.');
    }

    final plan = Map<String, dynamic>.from(decoded['plan'] as Map);
    final items = (decoded['exercises'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final db = await _db;
    return db.transaction((txn) async {
      final planId = await txn.insert('workout_plans', {
        'name': '${plan['name'] ?? 'برنامه واردشده'}',
        'notes': plan['notes'],
        'weekday': plan['weekday'],
        'load_strategy': plan['load_strategy'] ?? 'manual',
        'load_step': plan['load_step'] ?? 2.5,
        'recovery_reduction': plan['recovery_reduction'] ?? 10,
        'recovery_mode': plan['recovery_mode'] ?? 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final name = '${item['name'] ?? ''}'.trim();
        if (name.isEmpty) continue;

        final matches = await txn.query(
          'exercises',
          where: 'name = ? COLLATE NOCASE',
          whereArgs: [name],
          limit: 1,
        );

        final exerciseId = matches.isNotEmpty
            ? matches.first['id'] as int
            : await txn.insert('exercises', {
                'name': name,
                'muscle_group': item['muscle_group'],
                'equipment': item['equipment'],
                'notes': item['notes'],
                'is_favorite': 0,
                'exercise_mode': item['exercise_mode'] ?? 'reps',
                'tracking_type': item['tracking_type'] ?? 'strength',
                'is_bodyweight': item['is_bodyweight'] ?? 0,
                'per_side': item['per_side'] ?? 0,
                'guide_url': item['guide_url'],
                'created_at': DateTime.now().toIso8601String(),
              });

        await txn.insert('plan_exercises', {
          'plan_id': planId,
          'exercise_id': exerciseId,
          'position': index,
          'target_sets': item['target_sets'],
          'target_reps': item['target_reps'],
          'rest_seconds': item['rest_seconds'] ?? 90,
          'bar_weight': item['bar_weight'],
          'strategy_override': item['strategy_override'],
        });
      }

      return planId;
    });
  }
}
