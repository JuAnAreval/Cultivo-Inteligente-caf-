import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/cosechas/cosecha_service.dart';
import 'package:app_flutter_ai/screens/cosechas/add_cosecha_screen.dart';
import 'package:app_flutter_ai/screens/cosechas/cosecha_ai_chat_screen.dart';
import 'package:flutter/material.dart';

class CosechaListScreen extends StatefulWidget {
  const CosechaListScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  final String farmId;
  final String farmName;

  @override
  State<CosechaListScreen> createState() => _CosechaListScreenState();
}

class _CosechaListScreenState extends State<CosechaListScreen> {
  late Future<List<Map<String, dynamic>>> _cosechasFuture;

  @override
  void initState() {
    super.initState();
    _cosechasFuture = _loadCosechas();
  }

  Future<List<Map<String, dynamic>>> _loadCosechas() async {
    final response = await CosechaService.getAll();
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
        .where((item) => item['id_finca']?.toString() == widget.farmId)
        .toList();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _cosechasFuture = _loadCosechas();
    });
    await _cosechasFuture;
  }

  Future<void> _openAiChat() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CosechaAiChatScreen(
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
          content: Text('Cosecha registrada y listado actualizado.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openForm({Map<String, dynamic>? cosecha}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCosechaScreen(
          farmId: widget.farmId,
          farmName: widget.farmName,
          existingCosecha: cosecha,
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
            cosecha == null
                ? 'Cosecha registrada y listado actualizado.'
                : 'Cosecha actualizada correctamente.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteCosecha(Map<String, dynamic> cosecha) async {
    final cosechaId = (cosecha['id'] ?? '').toString();
    final fecha = (cosecha['fecha'] ?? 'esta cosecha').toString();
    if (cosechaId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar cosecha'),
          content: Text('Vas a eliminar el registro de cosecha del $fecha.'),
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
      await CosechaService.delete(cosechaId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cosecha del $fecha eliminada correctamente.'),
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
          content: Text('No se pudo eliminar la cosecha: $error'),
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
        title: Text('Cosechas - ${widget.farmName}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cosechasFuture,
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
                      'No se pudieron cargar las cosechas.\n${snapshot.error}',
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

          final cosechas = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _HeaderCard(
                  farmName: widget.farmName,
                  total: cosechas.length,
                  onOpenAi: _openAiChat,
                ),
                const SizedBox(height: 16),
                if (cosechas.isEmpty)
                  const _EmptyCard()
                else
                  ...cosechas.map(
                    (cosecha) => _CosechaCard(
                      cosecha: cosecha,
                      onEdit: () => _openForm(cosecha: cosecha),
                      onDelete: () => _deleteCosecha(cosecha),
                    ),
                  ),
                const SizedBox(height: 90),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAiChat,
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.surface,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Registrar con IA'),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.farmName,
    required this.total,
    required this.onOpenAi,
  });

  final String farmName;
  final int total;
  final VoidCallback onOpenAi;

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
            'Historial de cosechas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aquí verás las cosechas registradas de la finca y podrás crear nuevas con ayuda de IA.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.agriculture_rounded,
                        size: 18,
                        color: AppColors.moss,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$total cosechas registradas',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onOpenAi,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.moss,
                  foregroundColor: AppColors.surface,
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Chat IA'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CosechaCard extends StatelessWidget {
  const _CosechaCard({
    required this.cosecha,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> cosecha;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fecha = (cosecha['fecha'] ?? '').toString();
    final kilosCereza = (cosecha['kilos_cereza'] ?? '').toString();
    final kilosPergamino = (cosecha['kilos_pergamino'] ?? '').toString();
    final proceso = (cosecha['proceso'] ?? '').toString();
    final anio = (cosecha['anio'] ?? '').toString();
    final syncStatus = (cosecha['syncStatus'] ?? '').toString();

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fecha.isEmpty ? 'Cosecha sin fecha' : 'Cosecha del $fecha',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      proceso.isEmpty
                          ? 'Proceso pendiente por definir'
                          : 'Proceso $proceso',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (syncStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: syncStatus == 'synced'
                        ? AppColors.backgroundSoft
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    syncStatus == 'synced' ? 'Sincronizada' : 'Pendiente',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.soil,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(
                icon: Icons.scale_rounded,
                text: kilosCereza.isEmpty ? 'Sin cereza' : '$kilosCereza kg cereza',
              ),
              _Chip(
                icon: Icons.grain_rounded,
                text: kilosPergamino.isEmpty
                    ? 'Sin pergamino'
                    : '$kilosPergamino kg pergamino',
              ),
              _Chip(
                icon: Icons.calendar_today_rounded,
                text: anio.isEmpty ? 'Sin año' : anio,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.clayStrong,
                    side: const BorderSide(color: AppColors.sand),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.sand),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
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

class _Chip extends StatelessWidget {
  const _Chip({
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

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
            Icons.agriculture_outlined,
            color: AppColors.moss,
            size: 40,
          ),
          SizedBox(height: 14),
          Text(
            'Aún no hay cosechas registradas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Usa el chat de IA para registrar rápidamente la primera cosecha de esta finca.',
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
