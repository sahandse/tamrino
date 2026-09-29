import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class PublicExerciseLibraryService {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<int> importBundledLibrary() async {
    final raw = await rootBundle.loadString('assets/data/free_exercises.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Exercise library asset is invalid.');
    }
    final items = (decoded['exercises'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (items.isEmpty) {
      throw StateError('کتابخانه حرکات داخل این Build خالی است.');
    }

    final db = await _db;
    final existingRows = await db.query('exercises', columns: ['name']);
    final existing = existingRows
        .map((e) => (e['name'] as String? ?? '').trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    var inserted = 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        final name = '${item['name'] ?? ''}'.trim();
        if (name.isEmpty || existing.contains(name.toLowerCase())) continue;
        existing.add(name.toLowerCase());
        batch.insert('exercises', {
          'name': name,
          'muscle_group': _nullable(item['muscle_group']),
          'equipment': _nullable(item['equipment']),
          'notes': null,
          'is_favorite': 0,
          'exercise_mode': item['exercise_mode'] == 'timed' ? 'timed' : 'reps',
          'tracking_type': _tracking(item['tracking_type']),
          'is_bodyweight': item['is_bodyweight'] == 1 ? 1 : 0,
          'per_side': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
        inserted++;
      }
      await batch.commit(noResult: true);
    });
    return inserted;
  }

  Future<Map<String, Object?>> bundledInfo() async {
    final raw = await rootBundle.loadString('assets/data/free_exercises.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const {};
    final items = decoded['exercises'] as List? ?? const [];
    return {
      'source': decoded['source'],
      'source_commit': decoded['source_commit'],
      'license': decoded['license'],
      'count': items.length,
      'contains_media': decoded['contains_media'],
      'contains_instructions': decoded['contains_instructions'],
    };
  }

  String _tracking(Object? value) {
    final text = '$value';
    return {'strength', 'timed', 'cardio'}.contains(text) ? text : 'strength';
  }

  String? _nullable(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
