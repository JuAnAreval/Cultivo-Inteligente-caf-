import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/finca_service.dart';
import 'package:app_flutter_ai/core/services/session_service.dart';
import 'package:app_flutter_ai/screens/farms/add_farm_screen.dart';
import 'package:app_flutter_ai/screens/lots/lot_list_screen.dart';
import 'package:flutter/material.dart';

class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});

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

    if (rawList is List) {
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

    return [];
  }

  Future<void> _refresh() async {
    setState(() {
      _farmsFuture = _loadFarms();
    });
    await _farmsFuture;
  }

  Future<void> _openAddFarm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddFarmScreen(),
      ),
    );

    if (created == true) {
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finca creada y listado actualizado.'),
          backgroundColor: AppColors.success,
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
        title: const Text('Gestiona fincas'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
          if (farms.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.moss,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: const [
                  _EmptyFarmCard(),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: farms.length,
              itemBuilder: (context, index) {
                final farm = farms[index];
                return _FarmCard(
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
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFarm,
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.surface,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({
    required this.farm,
    required this.onTap,
  });

  final Map<String, dynamic> farm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nombre = (farm['nombre'] ?? '').toString();
    final ubicacion = (farm['ubicacion_texto'] ?? '').toString();
    final area = (farm['area_hectareas'] ?? '').toString();
    final latitud = (farm['latitud'] ?? '').toString();
    final longitud = (farm['longitud'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
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
                ubicacion.isEmpty ? 'Sin ubicacion registrada' : ubicacion,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
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
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.moss,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Ver lotes de esta finca',
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
            'Solo veras aqui las fincas creadas con tu usuario. Usa el boton + para registrar la primera.',
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
