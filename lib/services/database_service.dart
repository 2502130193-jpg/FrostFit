import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'frostfit.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workouts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            steps INTEGER NOT NULL,
            distance_meters REAL NOT NULL,
            route TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<int> saveWorkout(Workout workout) async =>
      (await database).insert('workouts', workout.toMap());

  Future<List<Workout>> getWorkouts() async {
    final rows = await (await database).query('workouts', orderBy: 'date DESC');
    return rows.map(Workout.fromMap).toList();
  }
}
