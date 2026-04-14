import 'package:app_flutter_ai/core/services/actividades/actividad_campo_service.dart';
import 'package:app_flutter_ai/core/services/cosechas/cosecha_service.dart';
import 'package:app_flutter_ai/core/services/fincas/finca_service.dart';
import 'package:app_flutter_ai/core/services/insumos/insumo_servies.dart';
import 'package:app_flutter_ai/core/services/lotes/lote_service.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';

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
      await _pushPendingActividades();
      await _pushPendingInsumos();
      await _pushPendingCosechas();
      await _pullFincas();
      await _pullLotes();
      await _pullActividades();
      await _pullInsumos();
      await _pullCosechas();
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

  static Future<void> _pushPendingActividades() async {
    final database = DatabaseHelper();
    final pending = await database.getPendingActividades();

    for (final actividad in pending) {
      final localId = (actividad['local_id'] as num).toInt();
      final remoteId = actividad['remote_id']?.toString();
      final status =
          actividad['sync_status']?.toString() ?? DatabaseHelper.synced;

      try {
        if (status == DatabaseHelper.pendingDelete) {
          if (remoteId != null && remoteId.isNotEmpty) {
            await ActividadCampoService.deleteRemote(remoteId);
          }
          await database.deleteLocalActividad(localId);
          continue;
        }

        var loteRemoteId = actividad['lote_remote_id']?.toString();
        if (loteRemoteId == null || loteRemoteId.isEmpty) {
          final loteLocalId = ActividadCampoService.toInt(actividad['lote_local_id']);
          if (loteLocalId != null) {
            final lote = await database.getLoteByLocalId(loteLocalId);
            loteRemoteId = lote?['remote_id']?.toString();
            if (loteRemoteId != null && loteRemoteId.isNotEmpty) {
              await database.updateLocalActividad(localId, {
                'lote_remote_id': loteRemoteId,
              });
            }
          }
        }

        if (status == DatabaseHelper.pendingCreate) {
          if (loteRemoteId == null || loteRemoteId.isEmpty) {
            continue;
          }

          final response = await ActividadCampoService.createRemote(
            ActividadCampoService.toRemotePayload({
              ...actividad,
              'lote_remote_id': loteRemoteId,
            }),
          );
          final remoteRecord = ActividadCampoService.extractRecord(response);

          await database.updateLocalActividad(localId, {
            'remote_id': remoteRecord['id']?.toString(),
            'lote_remote_id':
                remoteRecord['id_lote']?.toString() ?? loteRemoteId,
            'created_by':
                DatabaseHelper.toInt(remoteRecord['createdBy']) ??
                DatabaseHelper.toInt(actividad['created_by']),
            'workspace_id':
                remoteRecord['workspaceId']?.toString() ??
                actividad['workspace_id']?.toString(),
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
          if (loteRemoteId == null || loteRemoteId.isEmpty) {
            continue;
          }

          await ActividadCampoService.updateRemote(
            remoteId,
            ActividadCampoService.toRemotePayload({
              ...actividad,
              'lote_remote_id': loteRemoteId,
            }),
          );
          await database.updateLocalActividad(localId, {
            'sync_status': DatabaseHelper.synced,
            'last_synced_at': DateTime.now().toIso8601String(),
            'last_error': null,
          });
        }
      } catch (error) {
        await database.updateLocalActividad(localId, {
          'last_error': error.toString(),
        });
      }
    }
  }

  static Future<void> _pushPendingInsumos() async {
    final database = DatabaseHelper();
    final pending = await database.getPendingInsumos();

    for (final insumo in pending) {
      final localId = (insumo['local_id'] as num).toInt();
      final remoteId = insumo['remote_id']?.toString();
      final status = insumo['sync_status']?.toString() ?? DatabaseHelper.synced;

      try {
        if (status == DatabaseHelper.pendingDelete) {
          if (remoteId != null && remoteId.isNotEmpty) {
            await InsumoService.deleteRemote(remoteId);
          }
          await database.deleteLocalInsumo(localId);
          continue;
        }

        var loteRemoteId = insumo['lote_remote_id']?.toString();
        if (loteRemoteId == null || loteRemoteId.isEmpty) {
          final loteLocalId = InsumoService.toInt(insumo['lote_local_id']);
          if (loteLocalId != null) {
            final lote = await database.getLoteByLocalId(loteLocalId);
            loteRemoteId = lote?['remote_id']?.toString();
            if (loteRemoteId != null && loteRemoteId.isNotEmpty) {
              await database.updateLocalInsumo(localId, {
                'lote_remote_id': loteRemoteId,
              });
            }
          }
        }

        if (status == DatabaseHelper.pendingCreate) {
          if (loteRemoteId == null || loteRemoteId.isEmpty) {
            continue;
          }

          final response = await InsumoService.createRemote(
            InsumoService.toRemotePayload({
              ...insumo,
              'lote_remote_id': loteRemoteId,
            }),
          );
          final remoteRecord = InsumoService.extractRecord(response);

          await database.updateLocalInsumo(localId, {
            'remote_id': remoteRecord['id']?.toString(),
            'lote_remote_id':
                remoteRecord['id_lote']?.toString() ?? loteRemoteId,
            'created_by':
                DatabaseHelper.toInt(remoteRecord['createdBy']) ??
                DatabaseHelper.toInt(insumo['created_by']),
            'workspace_id':
                remoteRecord['workspaceId']?.toString() ??
                insumo['workspace_id']?.toString(),
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
          if (loteRemoteId == null || loteRemoteId.isEmpty) {
            continue;
          }

          await InsumoService.updateRemote(
            remoteId,
            InsumoService.toRemotePayload({
              ...insumo,
              'lote_remote_id': loteRemoteId,
            }),
          );
          await database.updateLocalInsumo(localId, {
            'sync_status': DatabaseHelper.synced,
            'last_synced_at': DateTime.now().toIso8601String(),
            'last_error': null,
          });
        }
      } catch (error) {
        await database.updateLocalInsumo(localId, {
          'last_error': error.toString(),
        });
      }
    }
  }

  static Future<void> _pushPendingCosechas() async {
    final database = DatabaseHelper();
    final pending = await database.getPendingCosechas();

    for (final cosecha in pending) {
      final localId = (cosecha['local_id'] as num).toInt();
      final remoteId = cosecha['remote_id']?.toString();
      final status = cosecha['sync_status']?.toString() ?? DatabaseHelper.synced;

      try {
        if (status == DatabaseHelper.pendingDelete) {
          if (remoteId != null && remoteId.isNotEmpty) {
            await CosechaService.deleteRemote(remoteId);
          }
          await database.deleteLocalCosecha(localId);
          continue;
        }

        var fincaRemoteId = cosecha['finca_remote_id']?.toString();
        if (fincaRemoteId == null || fincaRemoteId.isEmpty) {
          final fincaLocalId = CosechaService.toInt(cosecha['finca_local_id']);
          if (fincaLocalId != null) {
            final finca = await database.getFincaByLocalId(fincaLocalId);
            fincaRemoteId = finca?['remote_id']?.toString();
            if (fincaRemoteId != null && fincaRemoteId.isNotEmpty) {
              await database.updateLocalCosecha(localId, {
                'finca_remote_id': fincaRemoteId,
              });
            }
          }
        }

        if (status == DatabaseHelper.pendingCreate) {
          if (fincaRemoteId == null || fincaRemoteId.isEmpty) {
            continue;
          }

          final response = await CosechaService.createRemote(
            CosechaService.toRemotePayload({
              ...cosecha,
              'finca_remote_id': fincaRemoteId,
            }),
          );
          final remoteRecord = CosechaService.extractRecord(response);

          await database.updateLocalCosecha(localId, {
            'remote_id': remoteRecord['id']?.toString(),
            'finca_remote_id':
                remoteRecord['id_finca']?.toString() ?? fincaRemoteId,
            'created_by':
                DatabaseHelper.toInt(remoteRecord['createdBy']) ??
                DatabaseHelper.toInt(cosecha['created_by']),
            'workspace_id':
                remoteRecord['workspaceId']?.toString() ??
                cosecha['workspace_id']?.toString(),
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

          await CosechaService.updateRemote(
            remoteId,
            CosechaService.toRemotePayload({
              ...cosecha,
              'finca_remote_id': fincaRemoteId,
            }),
          );
          await database.updateLocalCosecha(localId, {
            'sync_status': DatabaseHelper.synced,
            'last_synced_at': DateTime.now().toIso8601String(),
            'last_error': null,
          });
        }
      } catch (error) {
        await database.updateLocalCosecha(localId, {
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

    final remoteIds = <String>{};
    for (final item in rawList.whereType<Map>()) {
      final record = Map<String, dynamic>.from(item);
      final remoteId = record['id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        remoteIds.add(remoteId);
      }
      await database.upsertRemoteFinca(record);
    }
    await database.removeMissingRemoteFincas(remoteIds);
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

    final remoteIds = <String>{};
    for (final item in rawList.whereType<Map>()) {
      final record = Map<String, dynamic>.from(item);
      final remoteId = record['id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        remoteIds.add(remoteId);
      }
      await database.upsertRemoteLote(record);
    }
    await database.removeMissingRemoteLotes(remoteIds);
  }

  static Future<void> _pullActividades() async {
    final database = DatabaseHelper();
    final response = await ActividadCampoService.fetchRemote(limit: 300);
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];

    if (rawList is! List) {
      return;
    }

    final remoteIds = <String>{};
    for (final item in rawList.whereType<Map>()) {
      final record = Map<String, dynamic>.from(item);
      final remoteId = record['id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        remoteIds.add(remoteId);
      }
      await database.upsertRemoteActividad(record);
    }
    await database.removeMissingRemoteActividades(remoteIds);
  }

  static Future<void> _pullInsumos() async {
    final database = DatabaseHelper();
    final response = await InsumoService.fetchRemote(limit: 300);
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];

    if (rawList is! List) {
      return;
    }

    final remoteIds = <String>{};
    for (final item in rawList.whereType<Map>()) {
      final record = Map<String, dynamic>.from(item);
      final remoteId = record['id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        remoteIds.add(remoteId);
      }
      await database.upsertRemoteInsumo(record);
    }
    await database.removeMissingRemoteInsumos(remoteIds);
  }

  static Future<void> _pullCosechas() async {
    final database = DatabaseHelper();
    final response = await CosechaService.fetchRemote(limit: 300);
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];

    if (rawList is! List) {
      return;
    }

    final remoteIds = <String>{};
    for (final item in rawList.whereType<Map>()) {
      final record = Map<String, dynamic>.from(item);
      final remoteId = record['id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        remoteIds.add(remoteId);
      }
      await database.upsertRemoteCosecha(record);
    }
    await database.removeMissingRemoteCosechas(remoteIds);
  }
}
