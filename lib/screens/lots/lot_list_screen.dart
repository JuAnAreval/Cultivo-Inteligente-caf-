import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/lote_service.dart';
import 'package:app_flutter_ai/screens/lots/add_lot_screen.dart';
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
    setState(() {
      _lotsFuture = _loadLots();
    });
    await _lotsFuture;
  }

  Future<void> _openAddLot() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLotScreen(
          farmId: widget.farmId,
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
          content: Text('Lote creado y listado actualizado.'),
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
          if (lots.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.moss,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _EmptyLotsCard(farmName: widget.farmName),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: lots.length,
              itemBuilder: (context, index) {
                final lot = lots[index];
                return _LotCard(lot: lot);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddLot,
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.surface,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot});

  final Map<String, dynamic> lot;

  @override
  Widget build(BuildContext context) {
    final nombre = (lot['nombre_lote'] ?? '').toString();
    final tipoCafe = (lot['tipo_cafe'] ?? '').toString();
    final edadCultivo = (lot['edad_cultivo'] ?? '').toString();
    final hectareas = (lot['hectareas_lote'] ?? '').toString();

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
            tipoCafe.isEmpty ? 'Tipo de cafe no definido' : tipoCafe,
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
              _LotChip(
                icon: Icons.timelapse_rounded,
                text: edadCultivo.isEmpty ? 'Edad no definida' : '$edadCultivo anos',
              ),
              _LotChip(
                icon: Icons.crop_landscape_rounded,
                text: hectareas.isEmpty ? 'Area no definida' : '$hectareas ha',
              ),
            ],
          ),
        ],
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
            'Aun no hay lotes creados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa el boton + para registrar el primer lote de $farmName.',
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
