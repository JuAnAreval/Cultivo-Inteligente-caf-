import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/fincas/finca_service.dart';
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
    setState(() {
      _farmsFuture = _loadFarms();
    });
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
            'Vas a eliminar "$farmName". Esta accion tambien puede afectar el trabajo relacionado a esta finca.',
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
                    'No se pudieron cargar las fincas.\n${snapshot.error}',
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

        final farms = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.moss,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.embedded ? 18 : 16,
              16,
              widget.embedded ? 124 : 96,
            ),
            children: [
              if (widget.embedded) const _FarmHeroCard(),
              if (widget.embedded) const SizedBox(height: 16),
              if (farms.isEmpty)
                const _EmptyFarmCard()
              else ...[
                _FarmSectionHeader(total: farms.length),
                const SizedBox(height: 12),
                ...farms.map(
                  (farm) => _FarmCard(
                    farm: farm,
                    onTap: () {
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
                    },
                    onEdit: () => _openFarmForm(farm: farm),
                    onDelete: () => _deleteFarm(farm),
                  ),
                ),
              ],
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
              child: FloatingActionButton(
                onPressed: () => _openFarmForm(),
                backgroundColor: AppColors.moss,
                foregroundColor: AppColors.surface,
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestiona fincas'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFarmForm(),
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.surface,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva finca'),
      ),
    );
  }
}

class _FarmHeroCard extends StatelessWidget {
  const _FarmHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fincas',
            style: TextStyle(
              color: AppColors.clayStrong,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tus fincas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Entra a cada finca para ver sus lotes, registrar actividades y mantener tu informacion organizada.',
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

class _FarmSectionHeader extends StatelessWidget {
  const _FarmSectionHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Listado de fincas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.sand),
          ),
          child: Text(
            '$total',
            style: const TextStyle(
              color: AppColors.moss,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({
    required this.farm,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> farm;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final nombre = (farm['nombre'] ?? '').toString();
    final ubicacion = (farm['ubicacion_texto'] ?? '').toString();
    final area = (farm['area_hectareas'] ?? '').toString();
    final latitud = (farm['latitud'] ?? '').toString();
    final longitud = (farm['longitud'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
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
                            nombre.isEmpty ? 'Finca sin nombre' : nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ubicacion.isEmpty
                                ? 'Sin ubicacion registrada'
                                : ubicacion,
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
                          tooltip: 'Editar finca',
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 8),
                        _CornerActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.danger,
                          tooltip: 'Eliminar finca',
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
                    _FarmChip(
                      icon: Icons.crop_landscape_rounded,
                      text: area.isEmpty ? 'Area no definida' : '$area ha',
                    ),
                    _FarmChip(
                      icon: Icons.my_location_rounded,
                      text: latitud.isEmpty ? 'Sin latitud' : latitud,
                    ),
                    _FarmChip(
                      icon: Icons.explore_rounded,
                      text: longitud.isEmpty ? 'Sin longitud' : longitud,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.moss,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Entrar a lotes de esta finca',
                      style: TextStyle(
                        color: AppColors.moss,
                        fontWeight: FontWeight.w700,
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

class _FarmChip extends StatelessWidget {
  const _FarmChip({
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

class _EmptyFarmCard extends StatelessWidget {
  const _EmptyFarmCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.home_work_outlined,
            color: AppColors.moss,
            size: 40,
          ),
          SizedBox(height: 14),
          Text(
            'Aun no hay fincas creadas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Usa el boton Nueva finca para registrar la primera y empezar a organizar tu campo.',
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
