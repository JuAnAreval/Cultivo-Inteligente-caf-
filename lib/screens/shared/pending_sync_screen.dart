import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:app_flutter_ai/core/services/shared/pending_sync_service.dart';
import 'package:flutter/material.dart';

class PendingSyncScreen extends StatefulWidget {
  const PendingSyncScreen({super.key});

  @override
  State<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends State<PendingSyncScreen> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    await PendingSyncService.refreshPendingCount();
    return DatabaseHelper().getPendingChangesDetails();
  }

  Future<void> _refresh() async {
    setState(() {
      _itemsFuture = _loadItems();
    });
    await _itemsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pendientes de sincronización'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.moss),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 44,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No fue posible cargar los pendientes.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _refresh,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.moss,
                        foregroundColor: AppColors.surface,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                _PendingSummaryCard(total: items.length),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const _EmptyPendingCard()
                else
                  ...items.map((item) => _PendingItemCard(item: item)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PendingSummaryCard extends StatelessWidget {
  const _PendingSummaryCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final subtitle = total == 0
        ? 'La cola local está limpia.'
        : 'Aquí puedes revisar qué registro sigue pendiente y si el backend devolvió algún error.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.sync_problem_rounded,
              color: AppColors.clayStrong,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total pendientes',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingItemCard extends StatelessWidget {
  const _PendingItemCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final module = (item['module'] ?? '').toString();
    final title = (item['title'] ?? '').toString();
    final subtitle = (item['subtitle'] ?? '').toString();
    final syncStatus = (item['syncStatus'] ?? '').toString();
    final lastError = (item['lastError'] ?? '').toString().trim();
    final updatedAt = (item['updatedAt'] ?? '').toString();
    final localId = (item['localId'] ?? '').toString();
    final remoteId = (item['remoteId'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForModule(module),
                  color: AppColors.moss,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module,
                      style: const TextStyle(
                        color: AppColors.clayStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title.isEmpty ? 'Registro sin título' : title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.schedule_rounded,
                text: _statusLabel(syncStatus),
              ),
              if (localId.isNotEmpty)
                _InfoChip(
                  icon: Icons.tag_rounded,
                  text: 'Local $localId',
                ),
              if (remoteId.isNotEmpty)
                _InfoChip(
                  icon: Icons.cloud_done_rounded,
                  text: 'Remote ${remoteId.length > 10 ? '${remoteId.substring(0, 10)}...' : remoteId}',
                ),
            ],
          ),
          if (updatedAt.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Actualizado: $updatedAt',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: lastError.isEmpty
                  ? AppColors.backgroundSoft
                  : const Color(0xFFFFF1EF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: lastError.isEmpty ? AppColors.sand : AppColors.danger,
              ),
            ),
            child: Text(
              lastError.isEmpty
                  ? 'Sin error registrado. Puede estar esperando otra relación o una nueva pasada de sincronización.'
                  : lastError,
              style: TextStyle(
                color: lastError.isEmpty
                    ? AppColors.textSecondary
                    : AppColors.danger,
                height: 1.45,
                fontWeight:
                    lastError.isEmpty ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForModule(String module) {
    switch (module) {
      case 'Fincas':
        return Icons.agriculture_rounded;
      case 'Lotes':
        return Icons.grid_view_rounded;
      case 'Actividades':
        return Icons.assignment_rounded;
      case 'Insumos':
        return Icons.inventory_2_rounded;
      case 'Cosechas':
        return Icons.grass_rounded;
      default:
        return Icons.sync_problem_rounded;
    }
  }

  static String _statusLabel(String syncStatus) {
    switch (syncStatus) {
      case DatabaseHelper.pendingCreate:
        return 'Pendiente crear';
      case DatabaseHelper.pendingUpdate:
        return 'Pendiente actualizar';
      case DatabaseHelper.pendingDelete:
        return 'Pendiente eliminar';
      default:
        return syncStatus.isEmpty ? 'Pendiente' : syncStatus;
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.moss),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPendingCard extends StatelessWidget {
  const _EmptyPendingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.cloud_done_rounded,
            color: AppColors.moss,
            size: 42,
          ),
          SizedBox(height: 14),
          Text(
            'No hay pendientes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Todo lo local ya quedó sincronizado o no hay cambios en cola.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
