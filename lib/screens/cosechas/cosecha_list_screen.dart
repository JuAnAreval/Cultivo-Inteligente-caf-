import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/cosechas/cosecha_service.dart';
import 'package:app_flutter_ai/core/widgets/cultiva_ui.dart';
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
    setState(() => _cosechasFuture = _loadCosechas());
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
    final fecha = formatSpanishDate((cosecha['fecha'] ?? '').toString());
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

  double _sumNumeric(
    List<Map<String, dynamic>> cosechas,
    String key,
  ) {
    return cosechas
        .map((item) => double.tryParse((item[key] ?? '').toString()) ?? 0)
        .fold(0, (previous, element) => previous + element);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildCultivaSecondaryAppBar(
        context: context,
        title: 'Cosechas',
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
                child: CultivaEmptyStateCard(
                  icon: Icons.error_outline_rounded,
                  title: 'No pudimos cargar las cosechas',
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

          final cosechas = snapshot.data ?? [];
          final totalCereza = _sumNumeric(cosechas, 'kilos_cereza');
          final totalPergamino = _sumNumeric(cosechas, 'kilos_pergamino');
          final currentYear = DateTime.now().year;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
              children: [
                CultivaHeroCard(
                  eyebrow: widget.farmName,
                  title: 'Historial de cosechas',
                  description:
                      'Consulta rápido lo recolectado este año y usa IA para registrar nuevas cosechas sin llenar el formulario completo.',
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
                  footer: Row(
                    children: [
                      Expanded(
                        child: CultivaMiniStat(
                          value: totalCereza.toStringAsFixed(
                            totalCereza.truncateToDouble() == totalCereza ? 0 : 1,
                          ),
                          label: 'kg cereza en $currentYear',
                        ),
                      ),
                      Expanded(
                        child: CultivaMiniStat(
                          value: totalPergamino.toStringAsFixed(
                            totalPergamino.truncateToDouble() == totalPergamino
                                ? 0
                                : 1,
                          ),
                          label: 'kg pergamino en $currentYear',
                          alignment: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (cosechas.isEmpty)
                  CultivaEmptyStateCard(
                    icon: Icons.agriculture_outlined,
                    title: 'Aún no hay cosechas registradas',
                    message:
                        'Usa el registro con IA para guardar la primera cosecha de esta finca de forma mucho más rápida.',
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
                  ...cosechas.map(
                    (cosecha) => _CosechaCard(
                      cosecha: cosecha,
                      onEdit: () => _openForm(cosecha: cosecha),
                      onDelete: () => _deleteCosecha(cosecha),
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

class _CosechaCard extends StatelessWidget {
  const _CosechaCard({
    required this.cosecha,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> cosecha;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  CultivaStatusBadge? _buildBadge(String syncStatus) {
    if (syncStatus.isEmpty) {
      return null;
    }

    if (syncStatus == 'synced') {
      return const CultivaStatusBadge(
        label: 'Sincronizada',
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
    final fecha = formatSpanishDate((cosecha['fecha'] ?? '').toString());
    final kilosCereza = (cosecha['kilos_cereza'] ?? '').toString();
    final kilosPergamino = (cosecha['kilos_pergamino'] ?? '').toString();
    final proceso = (cosecha['proceso'] ?? '').toString();
    final syncStatus = (cosecha['syncStatus'] ?? '').toString();

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
                      fecha.isEmpty ? 'Cosecha sin fecha' : fecha,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      proceso.isEmpty
                          ? 'Proceso pendiente por definir'
                          : 'Proceso $proceso',
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CultivaMiniStat(
                  value: kilosCereza.isEmpty ? '0' : kilosCereza,
                  label: 'kg cereza',
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: kilosPergamino.isEmpty ? '0' : kilosPergamino,
                  label: 'kg pergamino',
                  alignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: proceso.isEmpty ? 'Sin dato' : proceso,
                  label: 'proceso',
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
