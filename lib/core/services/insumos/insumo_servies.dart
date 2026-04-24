import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:app_flutter_ai/core/services/shared/http_client.dart';
import 'package:app_flutter_ai/core/services/shared/pending_sync_service.dart';

class InsumoService {
  static Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 100,
    String search = '',
  }) async {
    var insumos = await DatabaseHelper().getVisibleInsumos();

    if (search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      insumos = insumos.where((insumo) {
        return (insumo['insumo'] ?? '').toString().toLowerCase().contains(query) ||
            (insumo['ingredientes_activos'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query) ||
            (insumo['factura'] ?? '').toString().toLowerCase().contains(query);
      }).toList();
    }

    final normalized = insumos
        .skip((page - 1) * limit)
        .take(limit)
        .map(_toViewMap)
        .toList();

    return {
      'data': normalized,
      'totalItems': insumos.length,
      'hasNextPage': page * limit < insumos.length,
      'source': 'local',
    };
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final loteLocalId = toInt(data['id_lote']);
    if (loteLocalId == null) {
      throw Exception('El lote asociado no es válido.');
    }

    final lote = await DatabaseHelper().getLoteByLocalId(loteLocalId);
    if (lote == null) {
      throw Exception('No se encontro el lote asociado.');
    }

    final now = DateTime.now().toIso8601String();
    final localId = await DatabaseHelper().insertLocalInsumo({
      'lote_local_id': loteLocalId,
      'lote_remote_id': lote['remote_id']?.toString(),
      'insumo': data['insumo']?.toString(),
      'ingredientes_activos': data['ingredientes_activos']?.toString(),
      'fecha': data['fecha']?.toString(),
      'tipo': data['tipo']?.toString(),
      'origen': data['origen']?.toString(),
      'factura': data['factura']?.toString(),
      'created_by': SessionService.userId,
      'workspace_id': ApiConfig.workspaceId,
      'sync_status': DatabaseHelper.pendingCreate,
      'deleted': 0,
      'updated_at': now,
      'last_synced_at': null,
      'last_error': null,
    });

    final saved = await DatabaseHelper().getInsumoByLocalId(localId);
    await PendingSyncService.refreshPendingCount();
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
      throw Exception('Id de insumo inválido.');
    }

    final existing = await DatabaseHelper().getInsumoByLocalId(localId);
    if (existing == null) {
      throw Exception('No se encontro el insumo.');
    }

    final nextStatus =
        existing['remote_id'] == null
            ? DatabaseHelper.pendingCreate
            : DatabaseHelper.pendingUpdate;

    await DatabaseHelper().updateLocalInsumo(localId, {
      'insumo': data['insumo']?.toString(),
      'ingredientes_activos': data['ingredientes_activos']?.toString(),
      'fecha': data['fecha']?.toString(),
      'tipo': data['tipo']?.toString(),
      'origen': data['origen']?.toString(),
      'factura': data['factura']?.toString(),
      'sync_status': nextStatus,
      'updated_at': DateTime.now().toIso8601String(),
      'last_error': null,
    });

    final saved = await DatabaseHelper().getInsumoByLocalId(localId);
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
      throw Exception('Id de insumo inválido.');
    }

    final existing = await DatabaseHelper().getInsumoByLocalId(localId);
    if (existing == null) {
      return {'success': true};
    }

    if (existing['remote_id'] == null) {
      await DatabaseHelper().deleteLocalInsumo(localId);
    } else {
      await DatabaseHelper().updateLocalInsumo(localId, {
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
      ApiConfig.insumoUrl,
    ).replace(queryParameters: queryParameters).toString();
    return HttpClient.get(url);
  }

  static Future<Map<String, dynamic>> createRemote(
    Map<String, dynamic> data,
  ) async {
    return HttpClient.post(ApiConfig.insumoUrl, data);
  }

  static Future<Map<String, dynamic>> updateRemote(
    String id,
    Map<String, dynamic> data,
  ) async {
    return HttpClient.put('${ApiConfig.insumoUrl}/$id', data);
  }

  static Future<Map<String, dynamic>> deleteRemote(String id) async {
    return HttpClient.delete('${ApiConfig.insumoUrl}/$id');
  }

  static Map<String, dynamic> extractRecord(Map<String, dynamic> response) {
    final nested = response['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return response;
  }

  static Map<String, dynamic> toRemotePayload(Map<String, dynamic> data) {
    final payload = <String, dynamic>{
      'id_lote':
          data['lote_remote_id']?.toString() ?? data['id_lote']?.toString(),
      'insumo': _cleanText(data['insumo']),
      'ingredientes_activos': _cleanText(data['ingredientes_activos']),
      'fecha': _cleanText(data['fecha']),
      'tipo': _normalizeTipo(data['tipo']),
      'origen': _normalizeOrigen(data['origen']),
    };

    final factura = _cleanText(data['factura']);
    if (factura.isNotEmpty) {
      payload['factura'] = factura;
    }

    payload.removeWhere((key, value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        return value.trim().isEmpty;
      }
      return false;
    });

    return payload;
  }

  static Map<String, dynamic> _toViewMap(Map<String, dynamic> row) {
    return {
      'id': (row['local_id'] as num).toInt().toString(),
      'remoteId': row['remote_id']?.toString(),
      'id_lote': row['lote_local_id']?.toString(),
      'lote_remote_id': row['lote_remote_id']?.toString(),
      'insumo': row['insumo']?.toString() ?? '',
      'ingredientes_activos': row['ingredientes_activos']?.toString() ?? '',
      'fecha': row['fecha']?.toString(),
      'tipo': row['tipo']?.toString() ?? '',
      'origen': row['origen']?.toString() ?? '',
      'factura': row['factura']?.toString() ?? '',
      'createdBy': row['created_by'],
      'workspaceId': row['workspace_id'],
      'syncStatus': row['sync_status']?.toString() ?? DatabaseHelper.synced,
      'lastError': row['last_error']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  static int? toInt(dynamic value) => DatabaseHelper.toInt(value);

  static String _cleanText(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String _normalizeTipo(dynamic value) {
    final normalized = _cleanText(value).toLowerCase();
    if (normalized.contains('organ')) {
      return 'organico';
    }
    return 'convencional';
  }

  static String _normalizeOrigen(dynamic value) {
    final normalized = _cleanText(value).toLowerCase();
    if (normalized.contains('prop')) {
      return 'propio';
    }
    return 'comprado';
  }
}
