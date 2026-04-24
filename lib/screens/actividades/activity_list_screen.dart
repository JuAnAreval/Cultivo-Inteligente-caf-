import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/actividades/actividad_campo_service.dart';
import 'package:app_flutter_ai/core/widgets/cultiva_ui.dart';
import 'package:app_flutter_ai/screens/actividades/add_activity_screen.dart';
import 'package:app_flutter_ai/screens/actividades/activity_ai_chat_screen.dart';
import 'package:flutter/material.dart';

class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.farmName,
  });

  final String lotId;
  final String lotName;
  final String farmName;

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  late Future<List<Map<String, dynamic>>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = _loadActivities();
  }

  Future<List<Map<String, dynamic>>> _loadActivities() async {
    final response = await ActividadCampoService.getAll();
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
    setState(() => _activitiesFuture = _loadActivities());
    await _activitiesFuture;
  }

  Future<void> _openAiChat() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityAiChatScreen(
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
          content: Text('Actividad registrada y listado actualizado.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openForm({Map<String, dynamic>? activity}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddActivityScreen(
          lotId: widget.lotId,
          lotName: widget.lotName,
          farmName: widget.farmName,
          existingActivity: activity,
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
            activity == null
                ? 'Actividad registrada y listado actualizado.'
                : 'Actividad actualizada correctamente.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteActivity(Map<String, dynamic> activity) async {
    final activityId = (activity['id'] ?? '').toString();
    final activityName = (activity['actividad'] ?? 'esta actividad').toString();
    if (activityId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar actividad'),
          content: Text('Vas a eliminar "$activityName" de este lote.'),
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
      await ActividadCampoService.delete(activityId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Actividad "$activityName" eliminada correctamente.'),
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
          content: Text('No se pudo eliminar la actividad: $error'),
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
        title: 'Actividades',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _activitiesFuture,
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
                  title: 'No pudimos cargar las actividades',
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

          final activities = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
              children: [
                CultivaHeroCard(
                  eyebrow: '${widget.farmName} · ${widget.lotName}',
                  title: 'Actividades del lote',
                  description:
                      'Consulta el historial del lote y registra nuevas labores con IA cuando necesites ir más rápido.',
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
                        icon: Icons.event_note_rounded,
                        label:
                            '${activities.length} ${activities.length == 1 ? 'actividad' : 'actividades'}',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.moss,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (activities.isEmpty)
                  CultivaEmptyStateCard(
                    icon: Icons.event_note_rounded,
                    title: 'Aún no hay actividades',
                    message:
                        'Registra la primera actividad del lote para empezar a construir su historial de trabajo.',
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
                  ...activities.map(
                    (activity) => _ActivityCard(
                      activity: activity,
                      onEdit: () => _openForm(activity: activity),
                      onDelete: () => _deleteActivity(activity),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _shortText(String value, int maxLength) {
    final cleaned = value.trim();
    if (cleaned.length <= maxLength) {
      return cleaned;
    }
    return '${cleaned.substring(0, maxLength - 3)}...';
  }

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
    final fecha = formatSpanishDate((activity['fecha'] ?? '').toString());
    final actividad = (activity['actividad'] ?? '').toString();
    final aplicaciones = (activity['aplicaciones'] ?? '').toString();
    final dosis = (activity['dosis'] ?? '').toString();
    final observaciones =
        (activity['observaciones_responsable'] ?? '').toString();
    final syncStatus = (activity['syncStatus'] ?? '').toString();
    final aplicacionesResumen = _shortText(
      aplicaciones.isEmpty ? 'Sin dato' : aplicaciones,
      14,
    );
    final detalleResumen = _shortText(
      observaciones.isEmpty ? 'Sin dato' : observaciones,
      14,
    );

    return CultivaEntityCard(
      accentColor: AppColors.moss,
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
                      actividad.isEmpty
                          ? 'Actividad sin descripción'
                          : actividad,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fecha.isEmpty ? 'Fecha pendiente' : fecha,
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
                  value: aplicacionesResumen,
                  label: 'aplicación',
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: dosis.isEmpty ? 'Sin dato' : dosis,
                  label: 'dosis',
                  alignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: CultivaMiniStat(
                  value: detalleResumen,
                  label: 'detalle',
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
