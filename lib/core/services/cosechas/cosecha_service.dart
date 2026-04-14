import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:app_flutter_ai/core/services/shared/http_client.dart';
import 'package:app_flutter_ai/core/services/shared/sync_service.dart';

class CosechaService {
  static Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 100,
    String search = '',
  }) async {
    await SyncService.syncAll();

    var cosechas = await DatabaseHelper().getVisibleCosechas();

    if (search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      cosechas = cosechas.where((cosecha) {
        return (cosecha['proceso'] ?? '').toString().toLowerCase().contains(query) ||
            (cosecha['anio'] ?? '').toString().toLowerCase().contains(query);
      }).toList();
    }

    final normalized = cosechas
        .skip((page - 1) * limit)
        .take(limit)
        .map(_toViewMap)
        .toList();

    return {
      'data': normalized,
      'totalItems': cosechas.length,
      'hasNextPage': page * limit < cosechas.length,
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final fincaLocalId = toInt(data['id_finca']);
    if (fincaLocalId == null) {
      throw Exception('La finca asociada no es valida.');
    }

    final finca = await DatabaseHelper().getFincaByLocalId(fincaLocalId);
    if (finca == null) {
      throw Exception('No se encontro la finca asociada.');
    }

    final now = DateTime.now().toIso8601String();
    final localId = await DatabaseHelper().insertLocalCosecha({
      'finca_local_id': fincaLocalId,
      'finca_remote_id': finca['remote_id']?.toString(),
      'fecha': data['fecha']?.toString(),
      'kilos_cereza': DatabaseHelper.toDouble(data['kilos_cereza']),
      'kilos_pergamino': DatabaseHelper.toDouble(data['kilos_pergamino']),
      'proceso': data['proceso']?.toString(),
      'anio': toInt(data['anio'] ?? data['año']),
      'created_by': SessionService.userId,
      'workspace_id': ApiConfig.workspaceId,
      'sync_status': DatabaseHelper.pendingCreate,
      'deleted': 0,
      'updated_at': now,
      'last_synced_at': null,
      'last_error': null,
    });

    await SyncService.syncAll();
    final saved = await DatabaseHelper().getCosechaByLocalId(localId);
    return {
      'success': true,
      'data': saved == null ? null : _toViewMap(saved),
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> data,
  ) async {
    final localId = int.tryParse(id);
    if (localId == null) {
      throw Exception('Id de cosecha invalido.');
    }

    final existing = await DatabaseHelper().getCosechaByLocalId(localId);
    if (existing == null) {
      throw Exception('No se encontro la cosecha.');
    }

    final nextStatus =
        existing['remote_id'] == null
            ? DatabaseHelper.pendingCreate
            : DatabaseHelper.pendingUpdate;

    await DatabaseHelper().updateLocalCosecha(localId, {
      'fecha': data['fecha']?.toString(),
      'kilos_cereza': DatabaseHelper.toDouble(data['kilos_cereza']),
      'kilos_pergamino': DatabaseHelper.toDouble(data['kilos_pergamino']),
      'proceso': data['proceso']?.toString(),
      'anio': toInt(data['anio'] ?? data['año']),
      'sync_status': nextStatus,
      'updated_at': DateTime.now().toIso8601String(),
      'last_error': null,
    });

    await SyncService.syncAll();
    final saved = await DatabaseHelper().getCosechaByLocalId(localId);
    return {
      'success': true,
      'data': saved == null ? null : _toViewMap(saved),
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> delete(String id) async {
    final localId = int.tryParse(id);
    if (localId == null) {
      throw Exception('Id de cosecha invalido.');
    }

    final existing = await DatabaseHelper().getCosechaByLocalId(localId);
    if (existing == null) {
      return {'success': true};
    }

    if (existing['remote_id'] == null) {
      await DatabaseHelper().deleteLocalCosecha(localId);
    } else {
      await DatabaseHelper().updateLocalCosecha(localId, {
        'deleted': 1,
        'sync_status': DatabaseHelper.pendingDelete,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    await SyncService.syncAll();
    return {'success': true, 'source': 'local'};
  }

  static Future<Map<String, dynamic>> fetchRemote({
    int page = 1,
    int limit = 100,
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
      ApiConfig.cosechaUrl,
    ).replace(queryParameters: queryParameters).toString();
    return HttpClient.get(url);
  }

  static Future<Map<String, dynamic>> createRemote(
    Map<String, dynamic> data,
  ) async {
    return HttpClient.post(ApiConfig.cosechaUrl, data);
  }

  static Future<Map<String, dynamic>> updateRemote(
    String id,
    Map<String, dynamic> data,
  ) async {
    return HttpClient.patch('${ApiConfig.cosechaUrl}/$id', data);
  }

  static Future<Map<String, dynamic>> deleteRemote(String id) async {
    return HttpClient.delete('${ApiConfig.cosechaUrl}/$id');
  }

  static Map<String, dynamic> extractRecord(Map<String, dynamic> response) {
    final nested = response['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return response;
  }

  static Map<String, dynamic> toRemotePayload(Map<String, dynamic> data) {
    return {
      'id_finca':
          data['finca_remote_id']?.toString() ?? data['id_finca']?.toString(),
      'fecha': data['fecha']?.toString(),
      'kilos_cereza': DatabaseHelper.toDouble(data['kilos_cereza']),
      'kilos_pergamino': DatabaseHelper.toDouble(data['kilos_pergamino']),
      'proceso': data['proceso']?.toString(),
      'anio': toInt(data['anio'] ?? data['año']),
    };
  }

  static Map<String, dynamic> _toViewMap(Map<String, dynamic> row) {
    return {
      'id': (row['local_id'] as num).toInt().toString(),
      'remoteId': row['remote_id']?.toString(),
      'id_finca': row['finca_local_id']?.toString(),
      'finca_remote_id': row['finca_remote_id']?.toString(),
      'fecha': row['fecha']?.toString(),
      'kilos_cereza': row['kilos_cereza'],
      'kilos_pergamino': row['kilos_pergamino'],
      'proceso': row['proceso']?.toString() ?? '',
      'anio': row['anio'],
      'createdBy': row['created_by'],
      'workspaceId': row['workspace_id'],
      'syncStatus': row['sync_status']?.toString() ?? DatabaseHelper.synced,
      'lastError': row['last_error']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  static int? toInt(dynamic value) => DatabaseHelper.toInt(value);
}
