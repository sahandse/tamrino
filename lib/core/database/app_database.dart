import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const fileName = 'tamrino.db';
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    _database = await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE plan_exercises ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 90');
          await db.execute("ALTER TABLE workout_sets ADD COLUMN set_type TEXT NOT NULL DEFAULT 'normal'");
          await db.execute('ALTER TABLE workout_sets ADD COLUMN superset_group TEXT');
          await db.execute('ALTER TABLE body_metrics ADD COLUMN body_fat REAL');
          await db.execute('ALTER TABLE body_metrics ADD COLUMN chest REAL');
          await db.execute('ALTER TABLE body_metrics ADD COLUMN waist REAL');
          await db.execute('ALTER TABLE body_metrics ADD COLUMN arm REAL');
          await db.execute('ALTER TABLE body_metrics ADD COLUMN thigh REAL');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE exercises ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE workout_plans ADD COLUMN weekday INTEGER');
        }
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscle_group TEXT,
        equipment TEXT,
        notes TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        notes TEXT,
        weekday INTEGER,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE plan_exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        target_sets INTEGER,
        target_reps TEXT,
        rest_seconds INTEGER NOT NULL DEFAULT 90,
        FOREIGN KEY(plan_id) REFERENCES workout_plans(id) ON DELETE CASCADE,
        FOREIGN KEY(exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        notes TEXT,
        FOREIGN KEY(plan_id) REFERENCES workout_plans(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_sets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        reps INTEGER,
        weight REAL,
        rpe REAL,
        completed INTEGER NOT NULL DEFAULT 1,
        set_type TEXT NOT NULL DEFAULT 'normal',
        superset_group TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY(exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE body_metrics(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        measured_at TEXT NOT NULL,
        weight REAL,
        body_fat REAL,
        chest REAL,
        waist REAL,
        arm REAL,
        thigh REAL,
        notes TEXT
      )
    ''');
  }

  Future<String> databasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, fileName);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> reopen() async {
    await close();
    await database;
  }
}
