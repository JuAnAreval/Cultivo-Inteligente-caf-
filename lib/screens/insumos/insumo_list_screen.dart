import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/insumos/insumo_servies.dart';
import 'package:app_flutter_ai/core/widgets/cultiva_ui.dart';
import 'package:app_flutter_ai/screens/insumos/add_insumo_screen.dart';
import 'package:app_flutter_ai/screens/insumos/insumo_ai_chat_screen.dart';
import 'package:flutter/material.dart';

class InsumoListScreen extends StatefulWidget {
  const InsumoListScreen({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.farmName,
  });

  final String lotId;
  final String lotName;
  final String farmName;

  @override
  State<InsumoListScreen> createState() => _InsumoListScreenState();
}

class _InsumoListScreenState extends State<InsumoListScreen> {
  late Future<List<Map<String, dynamic>>> _insumosFuture;

  @override
  void initState() {
    super.initState();
    _insumosFuture = _loadInsumos();
  }

  Future<List<Map<String, dynamic>>> _loadInsumos() async {
    final response = await InsumoService.getAll();
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];

    if (rawList is! List) {
      return [];
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['id_lote']?.toString() == widget.lotId)
        .toList();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() => _insumosFuture = _loadInsumos());
    await _insumosFuture;
  }

  Future<void> _openForm({Map<String, dynamic>? insumo}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddInsumoScreen(
          lotId: widget.lotId,
          lotName: widget.lotName,
          farmName: widget.farmName,
          existingInsumo: insumo,
        ),
      ),
    );

    if (changed == true) {
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            insumo == null
                ? 'Insumo registrado y listado actualizado.'
                : 'Insumo actualizado correctamente.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAiChat() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InsumoAiChatScreen(
          lotId: widget.lotId,
          lotName: widget.lotName,
          farmName: widget.farmName,
        ),
      ),
    );

    if (created == true) {
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insumo registrado y listado actualizado.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteInsumo(Map<String, dynamic> insumo) async {
    final insumoId = (insumo['id'] ?? '').toString();
    final insumoName = (insumo['insumo'] ?? 'este insumo').toString();
    if (insumoId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar insumo'),
          content: Text('Vas a eliminar "$insumoName" de este lote.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.surface,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await InsumoService.delete(insumoId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insumo "$insumoName" eliminado correctamente.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar el insumo: $error'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildCultivaSecondaryAppBar(
        context: context,
        title: 'Insumos',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _insumosFuture,
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
                child: CultivaEmptyStateCard(
                  icon: Icons.error_outline_rounded,
                  title: 'No pudimos cargar los insumos',
                  message: '${snapshot.error}',
                  action: FilledButton(
                    onPressed: _refresh,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.moss,
                      foregroundColor: AppColors.surface,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ),
              ),
            );
          }

          final insumos = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
              children: [
                CultivaHeroCard(
                  eyebrow: '${widget.farmName} · ${widget.lotName}',
                  title: 'Insumos del lote',
                  description:
                      'Visualiza los productos registrados y usa IA para crear nuevos borradores de manera mas rapida.',
                  trailing: FilledButton.icon(
                    onPressed: _openAiChat,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.moss,
                      foregroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Chat IA'),
                  ),
                  footer: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      CultivaTintedChip(
                        icon: Icons.inventory_2_rounded,
                        label:
                            '${insumos.length} ${insumos.length == 1 ? 'insumo' : 'insumos'}',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.clayStrong,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (insumos.isEmpty)
                  CultivaEmptyStateCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aún no hay insumos registrados',
                    message:
                        'Registra el primer insumo del lote para tener un historial mas claro de aplicaciones y compras.',
                    action: FilledButton.icon(
                      onPressed: _openAiChat,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.moss,
                        foregroundColor: AppColors.surface,
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Registrar con IA'),
                    ),
                  )
                else
                  ...insumos.map(
                    (insumo) => _InsumoCard(
                      insumo: insumo,
                      onEdit: () => _openForm(insumo: insumo),
                      onDelete: () => _deleteInsumo(insumo),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: CultivaPillFab(
        icon: Icons.auto_awesome_rounded,
        label: 'Registrar con IA',
        onPressed: _openAiChat,
      ),
    );
  }
}

class _InsumoCard extends StatelessWidget {
  const _InsumoCard({
    required this.insumo,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> insumo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  CultivaStatusBadge? _buildBadge(String syncStatus) {
    if (syncStatus.isEmpty) {
      return null;
    }

    if (syncStatus == 'synced') {
      return const CultivaStatusBadge(
        label: 'Sincronizado',
        color: AppColors.success,
        backgroundColor: Color(0xFFEAF1E1),
      );
    }

    return const CultivaStatusBadge(
      label: 'Pendiente',
      color: AppColors.clayStrong,
      backgroundColor: AppColors.surfaceMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (insumo['insumo'] ?? '').toString();
    final ingredientes = (insumo['ingredientes_activos'] ?? '').toString();
    final fecha = formatSpanishDate((insumo['fecha'] ?? '').toString());
    final tipo = (insumo['tipo'] ?? '').toString();
    final origen = (insumo['origen'] ?? '').toString();
    final factura = (insumo['factura'] ?? '').toString();
    final syncStatus = (insumo['syncStatus'] ?? '').toString();

    return CultivaEntityCard(
      accentColor: AppColors.clayStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.isEmpty ? 'Insumo sin nombre' : nombre,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ingredientes.isEmpty
                          ? 'Sin ingredientes activos'
                          : ingredientes,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_buildBadge(syncStatus) != null) _buildBadge(syncStatus)!,
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    color: AppColors.surface,
                    surfaceTintColor: Colors.transparent,
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Editar'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Eliminar'),
                      ),
                    ],
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.backgroundSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.clayStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CultivaMiniStat(
                  value: fecha.isEmpty ? 'Sin dato' : fecha,
                  label: 'fecha',
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: tipo.isEmpty ? 'Sin dato' : tipo,
                  label: 'tipo',
                  alignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: origen.isEmpty ? 'Sin dato' : origen,
                  label: 'origen',
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          if (factura.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Factura: $factura',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.sand),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.clayStrong,
                    side: const BorderSide(color: AppColors.sand),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
