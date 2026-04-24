import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/lotes/lote_service.dart';
import 'package:app_flutter_ai/core/widgets/cultiva_ui.dart';
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
    setState(() => _lotsFuture = _loadLots());
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
            'Vas a eliminar "$lotName". Esta accion puede afectar los registros relacionados con este lote.',
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

  double _averageAge(List<Map<String, dynamic>> lots) {
    final ages = lots
        .map((lot) => double.tryParse((lot['edad_cultivo'] ?? '').toString()))
        .whereType<double>()
        .toList();
    if (ages.isEmpty) {
      return 0;
    }
    return ages.reduce((a, b) => a + b) / ages.length;
  }

  Set<String> _varieties(List<Map<String, dynamic>> lots) {
    return lots
        .map((lot) => (lot['tipo_cafe'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildCultivaSecondaryAppBar(
        context: context,
        title: 'Lotes',
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
                child: CultivaEmptyStateCard(
                  icon: Icons.error_outline_rounded,
                  title: 'No pudimos cargar los lotes',
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

          final lots = snapshot.data ?? [];
          final averageAge = _averageAge(lots);
          final varieties = _varieties(lots);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
              children: [
                CultivaHeroCard(
                  eyebrow: widget.farmName,
                  title: 'Lotes de cultivo',
                  description:
                      'Desde aqui puedes entrar a las actividades y a los insumos de cada lote sin perder el contexto de la finca.',
                  footer: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      CultivaTintedChip(
                        icon: Icons.grid_view_rounded,
                        label:
                            '${lots.length} ${lots.length == 1 ? 'lote' : 'lotes'}',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.moss,
                      ),
                      CultivaTintedChip(
                        icon: Icons.eco_rounded,
                        label: varieties.isEmpty
                            ? 'Variedad pendiente'
                            : '${varieties.length} variedades',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.clayStrong,
                      ),
                      CultivaTintedChip(
                        icon: Icons.timelapse_rounded,
                        label: averageAge <= 0
                            ? 'Edad pendiente'
                            : '${averageAge.toStringAsFixed(1)} años promedio',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (lots.isEmpty)
                  CultivaEmptyStateCard(
                    icon: Icons.grid_view_rounded,
                    title: 'Aún no tienes lotes en esta finca',
                    message:
                        'Registra el primer lote para empezar a llevar actividades e insumos con mejor orden.',
                    action: FilledButton.icon(
                      onPressed: () => _openLotForm(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.moss,
                        foregroundColor: AppColors.surface,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuevo lote'),
                    ),
                  )
                else
                  ...lots.map(
                    (lot) => _LotCard(
                      lot: lot,
                      onOpenActivities: () {
                        final lotId = (lot['id'] ?? '').toString();
                        final lotName =
                            (lot['nombre_lote'] ?? 'Lote').toString();
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
                        final lotName =
                            (lot['nombre_lote'] ?? 'Lote').toString();
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
      floatingActionButton: CultivaPillFab(
        icon: Icons.add_rounded,
        label: 'Nuevo lote',
        onPressed: () => _openLotForm(),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.lot,
    required this.onOpenActivities,
    required this.onOpenInsumos,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> lot;
  final VoidCallback onOpenActivities;
  final VoidCallback onOpenInsumos;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _shortText(String value, int maxLength) {
    final cleaned = value.trim();
    if (cleaned.length <= maxLength) {
      return cleaned;
    }
    return '${cleaned.substring(0, maxLength - 3)}...';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (lot['nombre_lote'] ?? '').toString();
    final tipoCafe = (lot['tipo_cafe'] ?? '').toString();
    final edadCultivo = (lot['edad_cultivo'] ?? '').toString();
    final hectareas = (lot['hectareas_lote'] ?? '').toString();
    final tipoCafeResumen = _shortText(
      tipoCafe.isEmpty ? 'Sin dato' : tipoCafe,
      14,
    );

    return CultivaEntityCard(
      accentColor: AppColors.clayStrong,
      onTap: onOpenActivities,
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
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tipoCafe.isEmpty
                          ? 'Variedad pendiente por definir'
                          : tipoCafe,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CultivaMiniStat(
                  value: tipoCafeResumen,
                  label: 'tipo café',
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: edadCultivo.isEmpty ? 'Sin dato' : edadCultivo,
                  label: 'años',
                  alignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: hectareas.isEmpty ? 'Sin dato' : hectareas,
                  label: 'hectáreas',
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.sand),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenActivities,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.moss,
                    side: const BorderSide(color: AppColors.sand),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Insumos'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
