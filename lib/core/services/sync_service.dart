import 'package:app_flutter_ai/core/services/database_helper.dart';
import 'package:app_flutter_ai/core/services/finca_service.dart';
import 'package:app_flutter_ai/core/services/lote_service.dart';

class SyncService {
  static bool _isSyncing = false;

  static Future<void> syncAll() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      await _pushPendingFincas();
      await _pushPendingLotes();
      await _pullFincas();
      await _pullLotes();
    } catch (_) {
      // El flujo offline debe seguir funcionando aunque la sincronizacion falle.
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _pushPendingFincas() async {
    final database = DatabaseHelper();
    final pending = await database.getPendingFincas();

    for (final finca in pending) {
      final localId = (finca['local_id'] as num).toInt();
      final remoteId = finca['remote_id']?.toString();
      final status = finca['sync_status']?.toString() ?? DatabaseHelper.synced;

      try {
        if (status == DatabaseHelper.pendingDelete) {
          if (remoteId != null && remoteId.isNotEmpty) {
            await FincaService.deleteRemote(remoteId);
          }
          await database.deleteLocalFinca(localId);
          continue;
        }

        if (status == DatabaseHelper.pendingCreate) {
          final response = await FincaService.createRemote(
            FincaService.toRemotePayload(finca),
          );
          final remoteRecord = FincaService.extractRecord(response);

          await database.updateLocalFinca(localId, {
            'remote_id': remoteRecord['id']?.toString(),
            'created_by':
                FincaService.toInt(remoteRecord['createdBy']) ??
                FincaService.toInt(finca['created_by']),
            'workspace_id':
                remoteRecord['workspaceId']?.toString() ??
                finca['workspace_id']?.toString(),
            'sync_status': DatabaseHelper.synced,
            'last_synced_at': DateTime.now().toIso8601String(),
            'last_error': null,
          });
          continue;
        }

        if (status == DatabaseHelper.pendingUpdate) {
          if (remoteId == null || remoteId.isEmpty) {
            continue;
          }

          await FincaService.updateRemote(
            remoteId,
            FincaService.toRemotePayload(finca),
          );
          await database.updateLocalFinca(localId, {
            'sync_status': DatabaseHelper.synced,
            'last_synced_at': DateTime.now().toIso8601String(),
            'last_error': null,
          });
        }
      } catch (error) {
        await database.updateLocalFinca(localId, {
          'last_error': error.toString(),
        });
      }
    }
  }

  static Future<void> _pushPendingLotes() async {
    final database = DatabaseHelper();
    final pending = await database.getPendingLotes();

    for (final lote in pending) {
      final localId = (lote['local_id'] as num).toInt();
      final remoteId = lote['remote_id']?.toString();
      final status = lote['sync_status']?.toString() ?? DatabaseHelper.synced;

      try {
        if (status == DatabaseHelper.pendingDelete) {
          if (remoteId != null && remoteId.isNotEmpty) {
            await LoteService.deleteRemote(remoteId);
          }
          await database.deleteLocalLote(localId);
          continue;
        }

        var fincaRemoteId = lote['finca_remote_id']?.toString();
        if (fincaRemoteId == null || fincaRemoteId.isEmpty) {
          final fincaLocalId = LoteService.toInt(lote['finca_local_id']);
          if (fincaLocalId != null) {
            final finca = await database.getFincaByLocalId(fincaLocalId);
            fincaRemoteId = finca?['remote_id']?.toString();
            if (fincaRemoteId != null && fincaRemoteId.isNotEmpty) {
              await database.updateLocalLote(localId, {
                'finca_remote_id': fincaRemoteId,
              });
            }
          }
        }

        if (status == DatabaseHelper.pendingCreate) {
          if (fincaRemoteId == null || fincaRemoteId.isEmpty) {
            continue;
          }

          final response = await LoteService.createRemote(
            LoteService.toRemotePayload({
              ...lote,
              'finca_remote_id': fincaRemoteId,
            }),
          );
          final remoteRecord = LoteService.extractRecord(response);

          await database.updateLocalLote(localId, {
            'remote_id': remoteRecord['id']?.toString(),
            'finca_remote_id':
                remoteRecord['id_finca']?.toString() ?? fincaRemoteId,
            'created_by':
                LoteService.toInt(remoteRecord['createdBy']) ??
                LoteService.toInt(lote['created_by']),
            'workspace_id':
                remoteRecord['workspaceId']?.toString() ??
                lote['workspace_id']?.toString(),
            'sync_status': DatabaseHelper.synced,
            'last_synced_at': DateTime.now().toIso8601String(),
            'last_error': null,
          });
          continue;
        }

        if (status == DatabaseHelper.pendingUpdate) {
          if (remoteId == null || remoteId.isEmpty) {
            continue;
          }
          if (fincaRemoteId == null || fincaRemoteId.isEmpty) {
            continue;
          }

          await LoteService.updateRemote(
            remoteId,
            LoteService.toRemotePayload({
              ...lote,
              'finca_remote_id': fincaRemoteId,
            }),
          );
          await database.updateLocalLote(localId, {
            'sync_status': DatabaseHelper.synced,
            'last_synced_at': DateTime.now().toIso8601String(),
            'last_error': null,
          });
        }
      } catch (error) {
        await database.updateLocalLote(localId, {
          'last_error': error.toString(),
        });
      }
    }
  }

  static Future<void> _pullFincas() async {
    final database = DatabaseHelper();
    final response = await FincaService.fetchRemote(limit: 200);
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];

    if (rawList is! List) {
      return;
    }

    for (final item in rawList.whereType<Map>()) {
      await database.upsertRemoteFinca(Map<String, dynamic>.from(item));
    }
  }

  static Future<void> _pullLotes() async {
    final database = DatabaseHelper();
    final response = await LoteService.fetchRemote(limit: 300);
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];

    if (rawList is! List) {
      return;
    }

    for (final item in rawList.whereType<Map>()) {
      await database.upsertRemoteLote(Map<String, dynamic>.from(item));
    }
  }
}
