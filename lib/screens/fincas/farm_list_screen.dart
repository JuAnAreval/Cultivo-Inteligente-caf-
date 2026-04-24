import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/fincas/finca_service.dart';
import 'package:app_flutter_ai/core/widgets/cultiva_ui.dart';
import 'package:app_flutter_ai/screens/cosechas/cosecha_list_screen.dart';
import 'package:app_flutter_ai/screens/fincas/add_farm_screen.dart';
import 'package:app_flutter_ai/screens/lotes/lot_list_screen.dart';
import 'package:flutter/material.dart';

class FarmListScreen extends StatefulWidget {
  const FarmListScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  late Future<List<Map<String, dynamic>>> _farmsFuture;

  @override
  void initState() {
    super.initState();
    _farmsFuture = _loadFarms();
  }

  Future<List<Map<String, dynamic>>> _loadFarms() async {
    final response = await FincaService.getAll();
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];
    final currentUserId = SessionService.userId;

    if (rawList is! List) {
      return [];
    }

    final farms = rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (currentUserId == null) {
      return farms;
    }

    return farms.where((farm) {
      final createdBy = farm['createdBy'];
      if (createdBy is int) {
        return createdBy == currentUserId;
      }
      if (createdBy is String) {
        return int.tryParse(createdBy) == currentUserId;
      }
      return false;
    }).toList();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() => _farmsFuture = _loadFarms());
    await _farmsFuture;
  }

  Future<void> _openFarmForm({Map<String, dynamic>? farm}) async {
    final createdOrUpdated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFarmScreen(existingFarm: farm),
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
            farm == null
                ? 'Finca creada y listado actualizado.'
                : 'Finca actualizada correctamente.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteFarm(Map<String, dynamic> farm) async {
    final farmId = (farm['id'] ?? '').toString();
    final farmName = (farm['nombre'] ?? 'esta finca').toString();
    if (farmId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar finca'),
          content: Text(
            'Vas a eliminar "$farmName". Esta accion tambien puede afectar el trabajo relacionado con esta finca.',
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
      await FincaService.delete(farmId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finca "$farmName" eliminada correctamente.'),
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
          content: Text('No se pudo eliminar la finca: $error'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openLots(Map<String, dynamic> farm) {
    final farmId = (farm['id'] ?? '').toString();
    final farmName = (farm['nombre'] ?? 'Finca').toString();
    if (farmId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LotListScreen(
          farmId: farmId,
          farmName: farmName,
        ),
      ),
    );
  }

  void _openCosechas(Map<String, dynamic> farm) {
    final farmId = (farm['id'] ?? '').toString();
    final farmName = (farm['nombre'] ?? 'Finca').toString();
    if (farmId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CosechaListScreen(
          farmId: farmId,
          farmName: farmName,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _farmsFuture,
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
                title: 'No pudimos cargar tus fincas',
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

        final farms = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.moss,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.embedded ? 18 : 16,
              16,
              widget.embedded ? 132 : 104,
            ),
            children: [
              CultivaHeroCard(
                eyebrow: 'Cultiva Tec',
                title: 'Tus fincas',
                description:
                    'Organiza cada finca, entra a sus lotes y manten tus registros de campo mucho mas claros.',
                footer: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    CultivaTintedChip(
                      icon: Icons.home_work_rounded,
                      label:
                          '${farms.length} ${farms.length == 1 ? 'finca registrada' : 'fincas registradas'}',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.clayStrong,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Listado de fincas',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  CultivaStatusBadge(
                    label: '${farms.length}',
                    color: AppColors.moss,
                    backgroundColor: AppColors.backgroundSoft,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (farms.isEmpty)
                CultivaEmptyStateCard(
                  icon: Icons.home_work_outlined,
                  title: 'Aún no tienes fincas registradas',
                  message:
                      'Crea tu primera finca para empezar a organizar lotes, cosechas y actividades.',
                  action: FilledButton.icon(
                    onPressed: () => _openFarmForm(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.moss,
                      foregroundColor: AppColors.surface,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nueva finca'),
                  ),
                )
              else
                ...farms.map(
                  (farm) => _FarmCard(
                    farm: farm,
                    onOpenLots: () => _openLots(farm),
                    onOpenCosechas: () => _openCosechas(farm),
                    onEdit: () => _openFarmForm(farm: farm),
                    onDelete: () => _deleteFarm(farm),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.backgroundSoft,
              AppColors.surfaceMuted,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildBody(),
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 122),
              child: CultivaPillFab(
                icon: Icons.add_rounded,
                label: 'Nueva finca',
                onPressed: () => _openFarmForm(),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildCultivaSecondaryAppBar(
        context: context,
        title: 'Fincas',
      ),
      body: _buildBody(),
      floatingActionButton: CultivaPillFab(
        icon: Icons.add_rounded,
        label: 'Nueva finca',
        onPressed: () => _openFarmForm(),
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({
    required this.farm,
    required this.onOpenLots,
    required this.onOpenCosechas,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> farm;
  final VoidCallback onOpenLots;
  final VoidCallback onOpenCosechas;
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
    final nombre = (farm['nombre'] ?? '').toString();
    final ubicacion = (farm['ubicacion_texto'] ?? '').toString();
    final area = (farm['area_hectareas'] ?? '').toString();
    final ubicacionResumen = _shortText(
      ubicacion.isEmpty ? 'Sin dato' : ubicacion,
      18,
    );

    return CultivaEntityCard(
      accentColor: AppColors.moss,
      onTap: onOpenLots,
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
                      nombre.isEmpty ? 'Finca sin nombre' : nombre,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ubicacion.isEmpty
                          ? 'Sin ubicación registrada'
                          : 'Lista para gestionar lotes y cosechas.',
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
                  value: area.isEmpty ? 'Sin dato' : area,
                  label: 'hectáreas',
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: ubicacionResumen,
                  label: 'ubicación',
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
                  onPressed: onOpenLots,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.moss,
                    side: const BorderSide(color: AppColors.sand),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Lotes'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenCosechas,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.clayStrong,
                    side: const BorderSide(color: AppColors.sand),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.agriculture_rounded),
                  label: const Text('Cosechas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
