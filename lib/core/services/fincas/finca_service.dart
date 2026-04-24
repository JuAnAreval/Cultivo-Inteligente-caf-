import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:app_flutter_ai/core/services/shared/http_client.dart';
import 'package:app_flutter_ai/core/services/shared/pending_sync_service.dart';

class FincaService {
  static Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 50,
    String search = '',
  }) async {
    final currentUserId = SessionService.userId;
    var fincas = await DatabaseHelper().getVisibleFincas(createdBy: currentUserId);

    if (search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      fincas = fincas.where((finca) {
        final nombre = (finca['nombre'] ?? '').toString().toLowerCase();
        final ubicacion =
            (finca['ubicacion_texto'] ?? '').toString().toLowerCase();
        return nombre.contains(query) || ubicacion.contains(query);
      }).toList();
    }

    final normalized = fincas
        .skip((page - 1) * limit)
        .take(limit)
        .map(_toViewMap)
        .toList();

    return {
      'data': normalized,
      'totalItems': fincas.length,
      'hasNextPage': page * limit < fincas.length,
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>?> getById(String id) async {
    final localId = int.tryParse(id);
    if (localId == null) {
      return null;
    }

    final finca = await DatabaseHelper().getFincaByLocalId(localId);
    if (finca == null) {
      return null;
    }

    return _toViewMap(finca);
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> finca) async {
    final now = DateTime.now().toIso8601String();
    final localId = await DatabaseHelper().insertLocalFinca({
      'nombre': finca['nombre']?.toString(),
      'ubicacion_texto': finca['ubicacion_texto']?.toString(),
      'latitud': toDouble(finca['latitud']),
      'longitud': toDouble(finca['longitud']),
      'area_hectareas': toDouble(finca['area_hectareas']),
      'created_by': SessionService.userId,
      'workspace_id': ApiConfig.workspaceId,
      'sync_status': DatabaseHelper.pendingCreate,
      'deleted': 0,
      'updated_at': now,
      'last_synced_at': null,
      'last_error': null,
    });

    final saved = await DatabaseHelper().getFincaByLocalId(localId);
    await PendingSyncService.refreshPendingCount();

    return {
      'success': true,
      'data': saved == null ? null : _toViewMap(saved),
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> finca,
  ) async {
    final localId = int.tryParse(id);
    if (localId == null) {
      throw Exception('Id de finca inválido.');
    }

    final existing = await DatabaseHelper().getFincaByLocalId(localId);
    if (existing == null) {
      throw Exception('No se encontro la finca.');
    }

    final nextStatus =
        existing['remote_id'] == null
            ? DatabaseHelper.pendingCreate
            : DatabaseHelper.pendingUpdate;

    await DatabaseHelper().updateLocalFinca(localId, {
      'nombre': finca['nombre']?.toString(),
      'ubicacion_texto': finca['ubicacion_texto']?.toString(),
      'latitud': toDouble(finca['latitud']),
      'longitud': toDouble(finca['longitud']),
      'area_hectareas': toDouble(finca['area_hectareas']),
      'sync_status': nextStatus,
      'updated_at': DateTime.now().toIso8601String(),
      'last_error': null,
    });

    final saved = await DatabaseHelper().getFincaByLocalId(localId);
    await PendingSyncService.refreshPendingCount();

    return {
      'success': true,
      'data': saved == null ? null : _toViewMap(saved),
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> delete(String id) async {
    final localId = int.tryParse(id);
    if (localId == null) {
      throw Exception('Id de finca inválido.');
    }

    final existing = await DatabaseHelper().getFincaByLocalId(localId);
    if (existing == null) {
      return {'success': true};
    }

    if (existing['remote_id'] == null) {
      await DatabaseHelper().deleteLocalFinca(localId);
    } else {
      await DatabaseHelper().updateLocalFinca(localId, {
        'deleted': 1,
        'sync_status': DatabaseHelper.pendingDelete,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    await PendingSyncService.refreshPendingCount();

    return {'success': true, 'source': 'local'};
  }

  static Future<Map<String, dynamic>> fetchRemote({
    int page = 1,
    int limit = 50,
    String search = '',
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };

    if (search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final url = Uri.parse(
      ApiConfig.fincaUrl,
    ).replace(queryParameters: queryParameters).toString();

    return HttpClient.get(url);
  }

  static Future<Map<String, dynamic>> createRemote(
    Map<String, dynamic> finca,
  ) async {
    return HttpClient.post(ApiConfig.fincaUrl, finca);
  }

  static Future<Map<String, dynamic>> updateRemote(
    String id,
    Map<String, dynamic> finca,
  ) async {
    return HttpClient.put('${ApiConfig.fincaUrl}/$id', finca);
  }

  static Future<Map<String, dynamic>> deleteRemote(String id) async {
    return HttpClient.delete('${ApiConfig.fincaUrl}/$id');
  }

  static Map<String, dynamic> extractRecord(Map<String, dynamic> response) {
    final nested = response['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return response;
  }

  static Map<String, dynamic> toRemotePayload(Map<String, dynamic> finca) {
    return {
      'nombre': finca['nombre']?.toString(),
      'ubicacion_texto': finca['ubicacion_texto']?.toString(),
      'latitud': toDouble(finca['latitud']),
      'longitud': toDouble(finca['longitud']),
      'area_hectareas': toDouble(finca['area_hectareas']),
    };
  }

  static Map<String, dynamic> _toViewMap(Map<String, dynamic> row) {
    return {
      'id': (row['local_id'] as num).toInt().toString(),
      'remoteId': row['remote_id']?.toString(),
      'nombre': row['nombre']?.toString() ?? '',
      'ubicacion_texto': row['ubicacion_texto']?.toString() ?? '',
      'latitud': row['latitud'],
      'longitud': row['longitud'],
      'area_hectareas': row['area_hectareas'],
      'createdBy': row['created_by'],
      'workspaceId': row['workspace_id'],
      'syncStatus': row['sync_status']?.toString() ?? DatabaseHelper.synced,
      'lastError': row['last_error']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  static double? toDouble(dynamic value) {
    return DatabaseHelper.toDouble(value);
  }

  static int? toInt(dynamic value) {
    return DatabaseHelper.toInt(value);
  }
}
