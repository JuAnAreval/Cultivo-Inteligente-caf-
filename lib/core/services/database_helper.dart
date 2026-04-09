import 'dart:convert';

import 'package:app_flutter_ai/core/models/task_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'tasks_ai.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT,
            state TEXT,
            color TEXT,
            category TEXT,
            details TEXT,
            dueDate TEXT,
            subActivities TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN dueDate TEXT');
        }
      },
    );
  }

  Future<void> insertTask(AppTask task) async {
    final db = await database;
    final data = task.toJson();
    data['subActivities'] = jsonEncode(data['subActivities']);

    await db.insert(
      'tasks',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTask(AppTask task) async {
    final db = await database;
    final data = task.toJson();
    data['subActivities'] = jsonEncode(data['subActivities']);

    await db.update(
      'tasks',
      data,
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AppTask>> getTasks() async {
    final db = await database;
    final rows = await db.query('tasks');

    return List.generate(rows.length, (index) {
      final taskMap = Map<String, dynamic>.from(rows[index]);
      taskMap['subActivities'] =
          jsonDecode(taskMap['subActivities'] as String);
      return AppTask.fromJson(taskMap);
    });
  }
}
