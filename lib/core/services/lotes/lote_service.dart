import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:app_flutter_ai/core/services/shared/http_client.dart';
import 'package:app_flutter_ai/core/services/shared/sync_service.dart';

class LoteService {
  static Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 100,
    String search = '',
  }) async {
    await SyncService.syncAll();

    var lotes = await DatabaseHelper().getVisibleLotes();

    if (search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      lotes = lotes.where((lote) {
        final nombre = (lote['nombre_lote'] ?? '').toString().toLowerCase();
        final tipo = (lote['tipo_cafe'] ?? '').toString().toLowerCase();
        return nombre.contains(query) || tipo.contains(query);
      }).toList();
    }

    final normalized = lotes
        .skip((page - 1) * limit)
        .take(limit)
        .map(_toViewMap)
        .toList();

    return {
      'data': normalized,
      'totalItems': lotes.length,
      'hasNextPage': page * limit < lotes.length,
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> lote) async {
    final fincaLocalId = toInt(lote['id_finca']);
    if (fincaLocalId == null) {
      throw Exception('La finca asociada no es valida.');
    }

    final finca = await DatabaseHelper().getFincaByLocalId(fincaLocalId);
    if (finca == null) {
      throw Exception('No se encontro la finca asociada.');
    }

    final now = DateTime.now().toIso8601String();
    final localId = await DatabaseHelper().insertLocalLote({
      'finca_local_id': fincaLocalId,
      'finca_remote_id': finca['remote_id']?.toString(),
      'nombre_lote': lote['nombre_lote']?.toString(),
      'tipo_cafe': lote['tipo_cafe']?.toString(),
      'edad_cultivo': toDouble(lote['edad_cultivo']),
      'hectareas_lote': toDouble(lote['hectareas_lote']),
      'created_by': SessionService.userId,
      'workspace_id': ApiConfig.workspaceId,
      'sync_status': DatabaseHelper.pendingCreate,
      'deleted': 0,
      'updated_at': now,
      'last_synced_at': null,
      'last_error': null,
    });

    await SyncService.syncAll();
    final saved = await DatabaseHelper().getLoteByLocalId(localId);

    return {
      'success': true,
      'data': saved == null ? null : _toViewMap(saved),
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> lote,
  ) async {
    final localId = int.tryParse(id);
    if (localId == null) {
      throw Exception('Id de lote invalido.');
    }

    final existing = await DatabaseHelper().getLoteByLocalId(localId);
    if (existing == null) {
      throw Exception('No se encontro el lote.');
    }

    final nextStatus =
        existing['remote_id'] == null
            ? DatabaseHelper.pendingCreate
            : DatabaseHelper.pendingUpdate;

    await DatabaseHelper().updateLocalLote(localId, {
      'nombre_lote': lote['nombre_lote']?.toString(),
      'tipo_cafe': lote['tipo_cafe']?.toString(),
      'edad_cultivo': toDouble(lote['edad_cultivo']),
      'hectareas_lote': toDouble(lote['hectareas_lote']),
      'sync_status': nextStatus,
      'updated_at': DateTime.now().toIso8601String(),
      'last_error': null,
    });

    await SyncService.syncAll();
    final saved = await DatabaseHelper().getLoteByLocalId(localId);

    return {
      'success': true,
      'data': saved == null ? null : _toViewMap(saved),
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> delete(String id) async {
    final localId = int.tryParse(id);
    if (localId == null) {
      throw Exception('Id de lote invalido.');
    }

    final existing = await DatabaseHelper().getLoteByLocalId(localId);
    if (existing == null) {
      return {'success': true};
    }

    if (existing['remote_id'] == null) {
      await DatabaseHelper().deleteLocalLote(localId);
    } else {
      await DatabaseHelper().updateLocalLote(localId, {
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
      ApiConfig.loteUrl,
    ).replace(queryParameters: queryParameters).toString();

    return HttpClient.get(url);
  }

  static Future<Map<String, dynamic>> createRemote(
    Map<String, dynamic> lote,
  ) async {
    return HttpClient.post(ApiConfig.loteUrl, lote);
  }

  static Future<Map<String, dynamic>> updateRemote(
    String id,
    Map<String, dynamic> lote,
  ) async {
    return HttpClient.patch('${ApiConfig.loteUrl}/$id', lote);
  }

  static Future<Map<String, dynamic>> deleteRemote(String id) async {
    return HttpClient.delete('${ApiConfig.loteUrl}/$id');
  }

  static Map<String, dynamic> extractRecord(Map<String, dynamic> response) {
    final nested = response['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return response;
  }

  static Map<String, dynamic> toRemotePayload(Map<String, dynamic> lote) {
    return {
      'id_finca':
          lote['finca_remote_id']?.toString() ?? lote['id_finca']?.toString(),
      'nombre_lote': lote['nombre_lote']?.toString(),
      'tipo_cafe': lote['tipo_cafe']?.toString(),
      'edad_cultivo': toDouble(lote['edad_cultivo']),
      'hectareas_lote': toDouble(lote['hectareas_lote']),
    };
  }

  static Map<String, dynamic> _toViewMap(Map<String, dynamic> row) {
    return {
      'id': (row['local_id'] as num).toInt().toString(),
      'remoteId': row['remote_id']?.toString(),
      'id_finca': row['finca_local_id']?.toString(),
      'finca_remote_id': row['finca_remote_id']?.toString(),
      'nombre_lote': row['nombre_lote']?.toString() ?? '',
      'tipo_cafe': row['tipo_cafe']?.toString() ?? '',
      'edad_cultivo': row['edad_cultivo'],
      'hectareas_lote': row['hectareas_lote'],
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
