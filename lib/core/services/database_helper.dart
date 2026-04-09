import 'dart:convert';

import 'package:app_flutter_ai/core/models/task_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  static Database? _database;

  static const String pendingCreate = 'pending_create';
  static const String pendingUpdate = 'pending_update';
  static const String pendingDelete = 'pending_delete';
  static const String synced = 'synced';

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
      version: 4,
      onCreate: (db, version) async {
        await _createTasksTable(db);
        await _createFincasTable(db);
        await _createLotesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _safeAddColumn(db, 'tasks', 'dueDate', 'TEXT');
        }
        if (oldVersion < 3) {
          await _createFincasTable(db);
          await _createLotesTable(db);
        }
        if (oldVersion < 4) {
          await _safeAddColumn(db, 'fincas_local', 'last_error', 'TEXT');
          await _safeAddColumn(db, 'lotes_local', 'last_error', 'TEXT');
        }
      },
    );
  }

  Future<void> _safeAddColumn(
    Database db,
    String tableName,
    String columnName,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (exists) {
      return;
    }

    await db.execute(
      'ALTER TABLE $tableName ADD COLUMN $columnName $definition',
    );
  }

  Future<void> _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks(
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
  }

  Future<void> _createFincasTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fincas_local(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT UNIQUE,
        nombre TEXT,
        ubicacion_texto TEXT,
        latitud REAL,
        longitud REAL,
        area_hectareas REAL,
        created_by INTEGER,
        workspace_id TEXT,
        sync_status TEXT NOT NULL DEFAULT '$synced',
        deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT,
        last_error TEXT
      )
    ''');
  }

  Future<void> _createLotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lotes_local(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT UNIQUE,
        finca_local_id INTEGER,
        finca_remote_id TEXT,
        nombre_lote TEXT,
        tipo_cafe TEXT,
        edad_cultivo REAL,
        hectareas_lote REAL,
        created_by INTEGER,
        workspace_id TEXT,
        sync_status TEXT NOT NULL DEFAULT '$synced',
        deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT,
        last_error TEXT
      )
    ''');
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

  Future<int> insertLocalFinca(Map<String, dynamic> finca) async {
    final db = await database;
    return db.insert(
      'fincas_local',
      finca,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLocalFinca(int localId, Map<String, dynamic> finca) async {
    final db = await database;
    await db.update(
      'fincas_local',
      finca,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteLocalFinca(int localId) async {
    final db = await database;
    await db.delete(
      'fincas_local',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleFincas({int? createdBy}) async {
    final db = await database;
    final whereParts = <String>['deleted = 0'];
    final whereArgs = <Object?>[];

    if (createdBy != null) {
      whereParts.add('created_by = ?');
      whereArgs.add(createdBy);
    }

    return db.query(
      'fincas_local',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getFincaByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'fincas_local',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getFincaByRemoteId(String remoteId) async {
    final db = await database;
    final rows = await db.query(
      'fincas_local',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getPendingFincas() async {
    final db = await database;
    return db.query(
      'fincas_local',
      where: 'sync_status != ?',
      whereArgs: [synced],
      orderBy: 'local_id ASC',
    );
  }

  Future<void> upsertRemoteFinca(Map<String, dynamic> finca) async {
    final remoteId = finca['id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      return;
    }

    final existing = await getFincaByRemoteId(remoteId);
    final now = DateTime.now().toIso8601String();
    final row = {
      'remote_id': remoteId,
      'nombre': finca['nombre']?.toString(),
      'ubicacion_texto': finca['ubicacion_texto']?.toString(),
      'latitud': toDouble(finca['latitud']),
      'longitud': toDouble(finca['longitud']),
      'area_hectareas': toDouble(finca['area_hectareas']),
      'created_by': toInt(finca['createdBy']),
      'workspace_id': finca['workspaceId']?.toString(),
      'updated_at': finca['updatedAt']?.toString() ?? now,
      'last_synced_at': now,
      'last_error': null,
      'deleted': 0,
      'sync_status': synced,
    };

    if (existing == null) {
      await insertLocalFinca(row);
      return;
    }

    final existingStatus = existing['sync_status']?.toString() ?? synced;
    if (existingStatus != synced) {
      return;
    }

    await updateLocalFinca((existing['local_id'] as num).toInt(), row);
  }

  Future<int> insertLocalLote(Map<String, dynamic> lote) async {
    final db = await database;
    return db.insert(
      'lotes_local',
      lote,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLocalLote(int localId, Map<String, dynamic> lote) async {
    final db = await database;
    await db.update(
      'lotes_local',
      lote,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteLocalLote(int localId) async {
    final db = await database;
    await db.delete(
      'lotes_local',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleLotes() async {
    final db = await database;
    return db.query(
      'lotes_local',
      where: 'deleted = 0',
      orderBy: 'updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getLoteByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'lotes_local',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getLoteByRemoteId(String remoteId) async {
    final db = await database;
    final rows = await db.query(
      'lotes_local',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getPendingLotes() async {
    final db = await database;
    return db.query(
      'lotes_local',
      where: 'sync_status != ?',
      whereArgs: [synced],
      orderBy: 'local_id ASC',
    );
  }

  Future<void> upsertRemoteLote(Map<String, dynamic> lote) async {
    final remoteId = lote['id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      return;
    }

    final existing = await getLoteByRemoteId(remoteId);
    final fincaRemoteId = lote['id_finca']?.toString();
    int? fincaLocalId;
    if (fincaRemoteId != null && fincaRemoteId.isNotEmpty) {
      final finca = await getFincaByRemoteId(fincaRemoteId);
      fincaLocalId = toInt(finca?['local_id']);
    }

    final now = DateTime.now().toIso8601String();
    final row = {
      'remote_id': remoteId,
      'finca_local_id': fincaLocalId,
      'finca_remote_id': fincaRemoteId,
      'nombre_lote': lote['nombre_lote']?.toString(),
      'tipo_cafe': lote['tipo_cafe']?.toString(),
      'edad_cultivo': toDouble(lote['edad_cultivo']),
      'hectareas_lote': toDouble(lote['hectareas_lote']),
      'created_by': toInt(lote['createdBy']),
      'workspace_id': lote['workspaceId']?.toString(),
      'updated_at': lote['updatedAt']?.toString() ?? now,
      'last_synced_at': now,
      'last_error': null,
      'deleted': 0,
      'sync_status': synced,
    };

    if (existing == null) {
      await insertLocalLote(row);
      return;
    }

    final existingStatus = existing['sync_status']?.toString() ?? synced;
    if (existingStatus != synced) {
      return;
    }

    await updateLocalLote((existing['local_id'] as num).toInt(), row);
  }

  static double? toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  static int? toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
