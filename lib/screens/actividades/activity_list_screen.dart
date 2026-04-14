import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/actividades/actividad_campo_service.dart';
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
    setState(() {
      _activitiesFuture = _loadActivities();
    });
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
      appBar: AppBar(
        title: Text('Actividades - ${widget.lotName}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
                      'No se pudieron cargar las actividades.\n${snapshot.error}',
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

          final activities = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.moss,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _ActivityHeaderCard(
                  lotName: widget.lotName,
                  farmName: widget.farmName,
                  onOpenAi: _openAiChat,
                ),
                const SizedBox(height: 16),
                if (activities.isEmpty)
                  const _EmptyActivityCard()
                else
                  ...activities.map(
                    (activity) => _ActivityCard(
                      activity: activity,
                      onEdit: () => _openForm(activity: activity),
                      onDelete: () => _deleteActivity(activity),
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

class _ActivityHeaderCard extends StatelessWidget {
  const _ActivityHeaderCard({
    required this.lotName,
    required this.farmName,
    required this.onOpenAi,
  });

  final String lotName;
  final String farmName;
  final VoidCallback onOpenAi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Historial del lote $lotName',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aqui veras el historial del lote y podras registrar nuevas actividades con ayuda de IA.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
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
                  child: const Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: AppColors.moss,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Historial local y sincronizado',
                          style: TextStyle(
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fecha = (activity['fecha'] ?? '').toString();
    final actividad = (activity['actividad'] ?? '').toString();
    final aplicaciones = (activity['aplicaciones'] ?? '').toString();
    final dosis = (activity['dosis'] ?? '').toString();
    final observaciones =
        (activity['observaciones_responsable'] ?? '').toString();
    final syncStatus = (activity['syncStatus'] ?? '').toString();

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
            children: [
              Expanded(
                child: Text(
                  actividad.isEmpty ? 'Actividad sin descripcion' : actividad,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
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
          const SizedBox(height: 10),
          if (fecha.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                fecha,
                style: const TextStyle(
                  color: AppColors.moss,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (aplicaciones.isNotEmpty || dosis.isNotEmpty || observaciones.isNotEmpty)
            const SizedBox(height: 12),
          if (aplicaciones.isNotEmpty)
            _DetailLine(label: 'Aplicaciones', value: aplicaciones),
          if (dosis.isNotEmpty) _DetailLine(label: 'Dosis', value: dosis),
          if (observaciones.isNotEmpty)
            _DetailLine(label: 'Observaciones', value: observaciones),
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

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
            Icons.event_note_rounded,
            color: AppColors.moss,
            size: 40,
          ),
          SizedBox(height: 14),
          Text(
            'Aun no hay actividades',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Usa el chat de IA para registrar rapidamente la primera actividad del lote.',
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
