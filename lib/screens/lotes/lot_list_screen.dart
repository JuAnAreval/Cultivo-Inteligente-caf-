import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/lotes/lote_service.dart';
import 'package:app_flutter_ai/screens/actividades/activity_list_screen.dart';
import 'package:app_flutter_ai/screens/insumos/insumo_list_screen.dart';
import 'package:app_flutter_ai/screens/lotes/add_lot_screen.dart';
import 'package:flutter/material.dart';

class LotListScreen extends StatefulWidget {
  const LotListScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  final String farmId;
  final String farmName;

  @override
  State<LotListScreen> createState() => _LotListScreenState();
}

class _LotListScreenState extends State<LotListScreen> {
  late Future<List<Map<String, dynamic>>> _lotsFuture;

  @override
  void initState() {
    super.initState();
    _lotsFuture = _loadLots();
  }

  Future<List<Map<String, dynamic>>> _loadLots() async {
    final response = await LoteService.getAll();
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
        .where((lot) => lot['id_finca']?.toString() == widget.farmId)
        .toList();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _lotsFuture = _loadLots();
    });
    await _lotsFuture;
  }

  Future<void> _openLotForm({Map<String, dynamic>? lot}) async {
    final createdOrUpdated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLotScreen(
          farmId: widget.farmId,
          farmName: widget.farmName,
          existingLot: lot,
        ),
      ),
    );

    if (createdOrUpdated == true) {
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lot == null
                ? 'Lote creado y listado actualizado.'
                : 'Lote actualizado correctamente.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteLot(Map<String, dynamic> lot) async {
    final lotId = (lot['id'] ?? '').toString();
    final lotName = (lot['nombre_lote'] ?? 'este lote').toString();
    if (lotId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar lote'),
          content: Text(
            'Vas a eliminar "$lotName". Esta accion puede afectar los registros relacionados a este lote.',
          ),
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
      await LoteService.delete(lotId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lote "$lotName" eliminado correctamente.'),
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
          content: Text('No se pudo eliminar el lote: $error'),
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
      appBar: AppBar(
        title: Text('Lotes de ${widget.farmName}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lotsFuture,
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
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No se pudieron cargar los lotes.\n${snapshot.error}',
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

          final lots = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
              children: [
                _LotHeaderCard(farmName: widget.farmName, totalLots: lots.length),
                const SizedBox(height: 16),
                if (lots.isEmpty)
                  _EmptyLotsCard(farmName: widget.farmName)
                else
                  ...lots.map(
                    (lot) => _LotCard(
                      lot: lot,
                      onTap: () {
                        final lotId = (lot['id'] ?? '').toString();
                        final lotName = (lot['nombre_lote'] ?? 'Lote').toString();

                        if (lotId.isEmpty) {
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityListScreen(
                              lotId: lotId,
                              lotName: lotName,
                              farmName: widget.farmName,
                            ),
                          ),
                        );
                      },
                      onOpenActivities: () {
                        final lotId = (lot['id'] ?? '').toString();
                        final lotName = (lot['nombre_lote'] ?? 'Lote').toString();

                        if (lotId.isEmpty) {
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityListScreen(
                              lotId: lotId,
                              lotName: lotName,
                              farmName: widget.farmName,
                            ),
                          ),
                        );
                      },
                      onOpenInsumos: () {
                        final lotId = (lot['id'] ?? '').toString();
                        final lotName = (lot['nombre_lote'] ?? 'Lote').toString();

                        if (lotId.isEmpty) {
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InsumoListScreen(
                              lotId: lotId,
                              lotName: lotName,
                              farmName: widget.farmName,
                            ),
                          ),
                        );
                      },
                      onEdit: () => _openLotForm(lot: lot),
                      onDelete: () => _deleteLot(lot),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLotForm(),
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.surface,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo lote'),
      ),
    );
  }
}

class _LotHeaderCard extends StatelessWidget {
  const _LotHeaderCard({
    required this.farmName,
    required this.totalLots,
  });

  final String farmName;
  final int totalLots;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            farmName,
            style: const TextStyle(
              color: AppColors.clayStrong,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gestiona tus lotes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Entra a cada lote para ver sus actividades o usa editar para actualizar su información.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$totalLots lotes',
              style: const TextStyle(
                color: AppColors.moss,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.lot,
    required this.onTap,
    required this.onOpenActivities,
    required this.onOpenInsumos,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> lot;
  final VoidCallback onTap;
  final VoidCallback onOpenActivities;
  final VoidCallback onOpenInsumos;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final nombre = (lot['nombre_lote'] ?? '').toString();
    final tipoCafe = (lot['tipo_cafe'] ?? '').toString();
    final edadCultivo = (lot['edad_cultivo'] ?? '').toString();
    final hectareas = (lot['hectareas_lote'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.sand),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                            nombre.isEmpty ? 'Lote sin nombre' : nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tipoCafe.isEmpty
                                ? 'Tipo de cafe no definido'
                                : tipoCafe,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        _CornerActionButton(
                          icon: Icons.edit_rounded,
                          color: AppColors.clayStrong,
                          tooltip: 'Editar lote',
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 8),
                        _CornerActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.danger,
                          tooltip: 'Eliminar lote',
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _LotChip(
                      icon: Icons.timelapse_rounded,
                      text: edadCultivo.isEmpty
                          ? 'Edad no definida'
                          : '$edadCultivo años',
                    ),
                    _LotChip(
                      icon: Icons.crop_landscape_rounded,
                      text: hectareas.isEmpty
                          ? 'Area no definida'
                          : '$hectareas hectareas',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenActivities,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.moss,
                          side: const BorderSide(color: AppColors.sand),
                        ),
                        icon: const Icon(Icons.event_note_rounded),
                        label: const Text('Actividades'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenInsumos,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.clayStrong,
                          side: const BorderSide(color: AppColors.sand),
                        ),
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: const Text('Insumos'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerActionButton extends StatelessWidget {
  const _CornerActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.backgroundSoft,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _LotChip extends StatelessWidget {
  const _LotChip({
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
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLotsCard extends StatelessWidget {
  const _EmptyLotsCard({required this.farmName});

  final String farmName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.grid_view_rounded,
            color: AppColors.moss,
            size: 40,
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no hay lotes creados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa el boton Nuevo lote para registrar el primero de $farmName.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
