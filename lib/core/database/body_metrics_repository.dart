import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class BodyMetricsRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<int> addMeasurement({
    required DateTime measuredAt,
    double? weight,
    double? bodyFat,
    double? chest,
    double? waist,
    double? arm,
    double? thigh,
    String? notes,
  }) async {
    final db = await _db;
    return db.insert('body_metrics', {
      'measured_at': measuredAt.toIso8601String(),
      'weight': weight,
      'body_fat': bodyFat,
      'chest': chest,
      'waist': waist,
      'arm': arm,
      'thigh': thigh,
      'notes': _emptyToNull(notes),
    });
  }

  Future<List<Map<String, Object?>>> getMeasurements({int limit = 100}) async {
    final db = await _db;
    return db.query(
      'body_metrics',
      orderBy: 'measured_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> getLatestMeasurement() async {
    final rows = await getMeasurements(limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteMeasurement(int id) async {
    final db = await _db;
    await db.delete('body_metrics', where: 'id = ?', whereArgs: [id]);
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
