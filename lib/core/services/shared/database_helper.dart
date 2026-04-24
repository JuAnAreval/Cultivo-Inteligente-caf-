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
      version: 6,
      onCreate: (db, version) async {
        await _createFincasTable(db);
        await _createLotesTable(db);
        await _createActividadesTable(db);
        await _createInsumosTable(db);
        await _createCosechasTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _createFincasTable(db);
          await _createLotesTable(db);
        }
        if (oldVersion < 4) {
          await _safeAddColumn(db, 'fincas_local', 'last_error', 'TEXT');
          await _safeAddColumn(db, 'lotes_local', 'last_error', 'TEXT');
        }
        if (oldVersion < 5) {
          await _createActividadesTable(db);
          await _createInsumosTable(db);
          await _createCosechasTable(db);
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

  Future<void> _createActividadesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS actividades_campo_local(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT UNIQUE,
        lote_local_id INTEGER,
        lote_remote_id TEXT,
        fecha TEXT,
        actividad TEXT,
        aplicaciones TEXT,
        dosis TEXT,
        observaciones_responsable TEXT,
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

  Future<void> _createInsumosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS insumos_local(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT UNIQUE,
        lote_local_id INTEGER,
        lote_remote_id TEXT,
        insumo TEXT,
        ingredientes_activos TEXT,
        fecha TEXT,
        tipo TEXT,
        origen TEXT,
        factura TEXT,
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

  Future<void> _createCosechasTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cosechas_local(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT UNIQUE,
        finca_local_id INTEGER,
        finca_remote_id TEXT,
        fecha TEXT,
        kilos_cereza REAL,
        kilos_pergamino REAL,
        proceso TEXT,
        anio INTEGER,
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

  Future<void> removeMissingRemoteFincas(Set<String> remoteIds) async {
    await _removeMissingRemoteRows(
      tableName: 'fincas_local',
      remoteIds: remoteIds,
    );
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

  Future<List<Map<String, dynamic>>> getVisibleLotesByFinca(
    int fincaLocalId,
  ) async {
    final db = await database;
    return db.query(
      'lotes_local',
      where: 'deleted = 0 AND finca_local_id = ?',
      whereArgs: [fincaLocalId],
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

  Future<void> removeMissingRemoteLotes(Set<String> remoteIds) async {
    await _removeMissingRemoteRows(
      tableName: 'lotes_local',
      remoteIds: remoteIds,
    );
  }

  Future<int> insertLocalActividad(Map<String, dynamic> actividad) async {
    final db = await database;
    return db.insert(
      'actividades_campo_local',
      actividad,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLocalActividad(
    int localId,
    Map<String, dynamic> actividad,
  ) async {
    final db = await database;
    await db.update(
      'actividades_campo_local',
      actividad,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteLocalActividad(int localId) async {
    final db = await database;
    await db.delete(
      'actividades_campo_local',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleActividades() async {
    final db = await database;
    return db.query(
      'actividades_campo_local',
      where: 'deleted = 0',
      orderBy: 'fecha DESC, updated_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleActividadesByLote(
    int loteLocalId,
  ) async {
    final db = await database;
    return db.query(
      'actividades_campo_local',
      where: 'deleted = 0 AND lote_local_id = ?',
      whereArgs: [loteLocalId],
      orderBy: 'fecha DESC, updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getActividadByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'actividades_campo_local',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getActividadByRemoteId(String remoteId) async {
    final db = await database;
    final rows = await db.query(
      'actividades_campo_local',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getPendingActividades() async {
    final db = await database;
    return db.query(
      'actividades_campo_local',
      where: 'sync_status != ?',
      whereArgs: [synced],
      orderBy: 'local_id ASC',
    );
  }

  Future<void> upsertRemoteActividad(Map<String, dynamic> actividad) async {
    final remoteId = actividad['id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      return;
    }

    final existing = await getActividadByRemoteId(remoteId);
    final loteRemoteId = actividad['id_lote']?.toString();
    int? loteLocalId;
    if (loteRemoteId != null && loteRemoteId.isNotEmpty) {
      final lote = await getLoteByRemoteId(loteRemoteId);
      loteLocalId = toInt(lote?['local_id']);
    }

    final now = DateTime.now().toIso8601String();
    final row = {
      'remote_id': remoteId,
      'lote_local_id': loteLocalId,
      'lote_remote_id': loteRemoteId,
      'fecha': actividad['fecha']?.toString(),
      'actividad': actividad['actividad']?.toString(),
      'aplicaciones': actividad['aplicaciones']?.toString(),
      'dosis': actividad['dosis']?.toString(),
      'observaciones_responsable':
          actividad['observaciones_responsable']?.toString(),
      'created_by': toInt(actividad['createdBy']),
      'workspace_id': actividad['workspaceId']?.toString(),
      'updated_at': actividad['updatedAt']?.toString() ?? now,
      'last_synced_at': now,
      'last_error': null,
      'deleted': 0,
      'sync_status': synced,
    };

    if (existing == null) {
      await insertLocalActividad(row);
      return;
    }

    final existingStatus = existing['sync_status']?.toString() ?? synced;
    if (existingStatus != synced) {
      return;
    }

    await updateLocalActividad((existing['local_id'] as num).toInt(), row);
  }

  Future<void> removeMissingRemoteActividades(Set<String> remoteIds) async {
    await _removeMissingRemoteRows(
      tableName: 'actividades_campo_local',
      remoteIds: remoteIds,
    );
  }

  Future<int> insertLocalInsumo(Map<String, dynamic> insumo) async {
    final db = await database;
    return db.insert(
      'insumos_local',
      insumo,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLocalInsumo(
      int localId, Map<String, dynamic> insumo) async {
    final db = await database;
    await db.update(
      'insumos_local',
      insumo,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteLocalInsumo(int localId) async {
    final db = await database;
    await db.delete(
      'insumos_local',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleInsumos() async {
    final db = await database;
    return db.query(
      'insumos_local',
      where: 'deleted = 0',
      orderBy: 'fecha DESC, updated_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleInsumosByLote(
    int loteLocalId,
  ) async {
    final db = await database;
    return db.query(
      'insumos_local',
      where: 'deleted = 0 AND lote_local_id = ?',
      whereArgs: [loteLocalId],
      orderBy: 'fecha DESC, updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getInsumoByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'insumos_local',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getInsumoByRemoteId(String remoteId) async {
    final db = await database;
    final rows = await db.query(
      'insumos_local',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getPendingInsumos() async {
    final db = await database;
    return db.query(
      'insumos_local',
      where: 'sync_status != ?',
      whereArgs: [synced],
      orderBy: 'local_id ASC',
    );
  }

  Future<void> upsertRemoteInsumo(Map<String, dynamic> insumo) async {
    final remoteId = insumo['id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      return;
    }

    final existing = await getInsumoByRemoteId(remoteId);
    final loteRemoteId = insumo['id_lote']?.toString();
    int? loteLocalId;
    if (loteRemoteId != null && loteRemoteId.isNotEmpty) {
      final lote = await getLoteByRemoteId(loteRemoteId);
      loteLocalId = toInt(lote?['local_id']);
    }

    final now = DateTime.now().toIso8601String();
    final row = {
      'remote_id': remoteId,
      'lote_local_id': loteLocalId,
      'lote_remote_id': loteRemoteId,
      'insumo': insumo['insumo']?.toString(),
      'ingredientes_activos': insumo['ingredientes_activos']?.toString(),
      'fecha': insumo['fecha']?.toString(),
      'tipo': insumo['tipo']?.toString(),
      'origen': insumo['origen']?.toString(),
      'factura': insumo['factura']?.toString(),
      'created_by': toInt(insumo['createdBy']),
      'workspace_id': insumo['workspaceId']?.toString(),
      'updated_at': insumo['updatedAt']?.toString() ?? now,
      'last_synced_at': now,
      'last_error': null,
      'deleted': 0,
      'sync_status': synced,
    };

    if (existing == null) {
      await insertLocalInsumo(row);
      return;
    }

    final existingStatus = existing['sync_status']?.toString() ?? synced;
    if (existingStatus != synced) {
      return;
    }

    await updateLocalInsumo((existing['local_id'] as num).toInt(), row);
  }

  Future<void> removeMissingRemoteInsumos(Set<String> remoteIds) async {
    await _removeMissingRemoteRows(
      tableName: 'insumos_local',
      remoteIds: remoteIds,
    );
  }

  Future<int> insertLocalCosecha(Map<String, dynamic> cosecha) async {
    final db = await database;
    return db.insert(
      'cosechas_local',
      cosecha,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLocalCosecha(
    int localId,
    Map<String, dynamic> cosecha,
  ) async {
    final db = await database;
    await db.update(
      'cosechas_local',
      cosecha,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteLocalCosecha(int localId) async {
    final db = await database;
    await db.delete(
      'cosechas_local',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleCosechas() async {
    final db = await database;
    return db.query(
      'cosechas_local',
      where: 'deleted = 0',
      orderBy: 'fecha DESC, updated_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getVisibleCosechasByFinca(
    int fincaLocalId,
  ) async {
    final db = await database;
    return db.query(
      'cosechas_local',
      where: 'deleted = 0 AND finca_local_id = ?',
      whereArgs: [fincaLocalId],
      orderBy: 'fecha DESC, updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getCosechaByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'cosechas_local',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getCosechaByRemoteId(String remoteId) async {
    final db = await database;
    final rows = await db.query(
      'cosechas_local',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getPendingCosechas() async {
    final db = await database;
    return db.query(
      'cosechas_local',
      where: 'sync_status != ?',
      whereArgs: [synced],
      orderBy: 'local_id ASC',
    );
  }

  Future<void> upsertRemoteCosecha(Map<String, dynamic> cosecha) async {
    final remoteId = cosecha['id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      return;
    }

    final existing = await getCosechaByRemoteId(remoteId);
    final fincaRemoteId = cosecha['id_finca']?.toString();
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
      'fecha': cosecha['fecha']?.toString(),
      'kilos_cereza': toDouble(cosecha['kilos_cereza']),
      'kilos_pergamino': toDouble(cosecha['kilos_pergamino']),
      'proceso': cosecha['proceso']?.toString(),
      'anio': toInt(cosecha['anio'] ?? cosecha['año']),
      'created_by': toInt(cosecha['createdBy']),
      'workspace_id': cosecha['workspaceId']?.toString(),
      'updated_at': cosecha['updatedAt']?.toString() ?? now,
      'last_synced_at': now,
      'last_error': null,
      'deleted': 0,
      'sync_status': synced,
    };

    if (existing == null) {
      await insertLocalCosecha(row);
      return;
    }

    final existingStatus = existing['sync_status']?.toString() ?? synced;
    if (existingStatus != synced) {
      return;
    }

    await updateLocalCosecha((existing['local_id'] as num).toInt(), row);
  }

  Future<void> removeMissingRemoteCosechas(Set<String> remoteIds) async {
    await _removeMissingRemoteRows(
      tableName: 'cosechas_local',
      remoteIds: remoteIds,
    );
  }

  Future<int> getPendingChangesCount() async {
    final fincas = await _countPendingRows('fincas_local');
    final lotes = await _countPendingRows('lotes_local');
    final actividades = await _countPendingRows('actividades_campo_local');
    final insumos = await _countPendingRows('insumos_local');
    final cosechas = await _countPendingRows('cosechas_local');

    return fincas + lotes + actividades + insumos + cosechas;
  }

  Future<List<Map<String, dynamic>>> getPendingChangesDetails() async {
    final items = <Map<String, dynamic>>[
      ...await _mapPendingFincas(),
      ...await _mapPendingLotes(),
      ...await _mapPendingActividades(),
      ...await _mapPendingInsumos(),
      ...await _mapPendingCosechas(),
    ];

    items.sort((a, b) {
      final left = (a['updatedAt'] ?? '').toString();
      final right = (b['updatedAt'] ?? '').toString();
      return right.compareTo(left);
    });

    return items;
  }

  Future<void> _removeMissingRemoteRows({
    required String tableName,
    required Set<String> remoteIds,
  }) async {
    final db = await database;
    final syncedRows = await db.query(
      tableName,
      columns: ['local_id', 'remote_id'],
      where: 'remote_id IS NOT NULL AND sync_status = ?',
      whereArgs: [synced],
    );

    for (final row in syncedRows) {
      final remoteId = row['remote_id']?.toString();
      if (remoteId == null || remoteId.isEmpty) {
        continue;
      }
      if (remoteIds.contains(remoteId)) {
        continue;
      }

      await db.delete(
        tableName,
        where: 'local_id = ?',
        whereArgs: [row['local_id']],
      );
    }
  }

  Future<int> _countPendingRows(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $tableName WHERE sync_status != ?',
      [synced],
    );

    if (result.isEmpty) {
      return 0;
    }

    return toInt(result.first['total']) ?? 0;
  }

  Future<List<Map<String, dynamic>>> _mapPendingFincas() async {
    final rows = await getPendingFincas();
    return rows.map((row) {
      return {
        'module': 'Fincas',
        'title': row['nombre']?.toString() ?? 'Finca sin nombre',
        'subtitle': row['ubicacion_texto']?.toString() ?? '',
        'syncStatus': row['sync_status']?.toString() ?? pendingCreate,
        'lastError': row['last_error']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
        'localId': row['local_id']?.toString(),
        'remoteId': row['remote_id']?.toString(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _mapPendingLotes() async {
    final rows = await getPendingLotes();
    return rows.map((row) {
      return {
        'module': 'Lotes',
        'title': row['nombre_lote']?.toString() ?? 'Lote sin nombre',
        'subtitle': row['tipo_cafe']?.toString() ?? '',
        'syncStatus': row['sync_status']?.toString() ?? pendingCreate,
        'lastError': row['last_error']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
        'localId': row['local_id']?.toString(),
        'remoteId': row['remote_id']?.toString(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _mapPendingActividades() async {
    final rows = await getPendingActividades();
    return rows.map((row) {
      final fecha = row['fecha']?.toString() ?? '';
      return {
        'module': 'Actividades',
        'title': row['actividad']?.toString() ?? 'Actividad sin descripcion',
        'subtitle': fecha.isEmpty ? '' : 'Fecha: $fecha',
        'syncStatus': row['sync_status']?.toString() ?? pendingCreate,
        'lastError': row['last_error']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
        'localId': row['local_id']?.toString(),
        'remoteId': row['remote_id']?.toString(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _mapPendingInsumos() async {
    final rows = await getPendingInsumos();
    return rows.map((row) {
      final fecha = row['fecha']?.toString() ?? '';
      return {
        'module': 'Insumos',
        'title': row['insumo']?.toString() ?? 'Insumo sin nombre',
        'subtitle': fecha.isEmpty ? '' : 'Fecha: $fecha',
        'syncStatus': row['sync_status']?.toString() ?? pendingCreate,
        'lastError': row['last_error']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
        'localId': row['local_id']?.toString(),
        'remoteId': row['remote_id']?.toString(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _mapPendingCosechas() async {
    final rows = await getPendingCosechas();
    return rows.map((row) {
      final fecha = row['fecha']?.toString() ?? '';
      final proceso = row['proceso']?.toString() ?? '';
      return {
        'module': 'Cosechas',
        'title': fecha.isEmpty ? 'Cosecha sin fecha' : 'Cosecha del $fecha',
        'subtitle': proceso.isEmpty ? '' : 'Proceso: $proceso',
        'syncStatus': row['sync_status']?.toString() ?? pendingCreate,
        'lastError': row['last_error']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
        'localId': row['local_id']?.toString(),
        'remoteId': row['remote_id']?.toString(),
      };
    }).toList();
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
