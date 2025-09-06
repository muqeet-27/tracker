import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DB {
  static final DB _instance = DB._internal();
  DB._internal();
  factory DB() => _instance;

  Database? _db;

  Future<Database> database() async {
    if (_db != null) return _db!;
    Directory dir = await getApplicationDocumentsDirectory();
    String path = join(dir.path, 'hse_tracker.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        custom_rate REAL
      );
    ''');
    await db.execute('''
      CREATE TABLE shifts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        start_time TEXT,
        end_time TEXT,
        default_hours REAL NOT NULL,
        hourly_rate REAL NOT NULL,
        notes TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        worker_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL,
        hours_override REAL,
        notes TEXT,
        UNIQUE(date, worker_id) ON CONFLICT REPLACE,
        FOREIGN KEY(worker_id) REFERENCES workers(id),
        FOREIGN KEY(shift_id) REFERENCES shifts(id)
      );
    ''');
    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        worker_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        method TEXT,
        notes TEXT,
        FOREIGN KEY(worker_id) REFERENCES workers(id)
      );
    ''');

    await db.insert('workers', {'name': 'Ramesh Kumar', 'role': 'Mason', 'active': 1});
    await db.insert('workers', {'name': 'Sita Devi', 'role': 'Helper', 'active': 1});
    await db.insert('workers', {'name': 'Arjun Singh', 'role': 'Carpenter', 'active': 1});

    await db.insert('shifts', {'name': 'Full Day', 'start_time': '09:00', 'end_time': '18:00', 'default_hours': 8, 'hourly_rate': 120, 'notes': '1 hour break not paid'});
    await db.insert('shifts', {'name': 'Half Day', 'start_time': '09:00', 'end_time': '13:00', 'default_hours': 4, 'hourly_rate': 120});
    await db.insert('shifts', {'name': 'Night', 'start_time': '20:00', 'end_time': '04:00', 'default_hours': 8, 'hourly_rate': 150, 'notes': 'Night premium'});
  }

  Future<List<Map<String, Object?>>> query(String table, {String? where, List<Object?>? whereArgs, String? orderBy}) async {
    final db = await database();
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> insert(String table, Map<String, Object?> data) async {
    final db = await database();
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, Object?> data, {required String where, required List<Object?> whereArgs}) async {
    final db = await database();
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {required String where, required List<Object?> whereArgs}) async {
    final db = await database();
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? args]) async {
    final db = await database();
    return db.rawQuery(sql, args);
  }
}
