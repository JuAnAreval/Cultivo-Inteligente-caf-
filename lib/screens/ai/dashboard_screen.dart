import 'dart:io';

import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/models/task_model.dart';
import 'package:app_flutter_ai/core/providers/task_provider.dart';
import 'package:app_flutter_ai/core/services/llm_service.dart';
import 'package:app_flutter_ai/screens/ai/widgets/ai_chat_block.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _modelFileName = 'qwen_2_5_1_5b.task';
  static const String _modelUrl =
      'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';

  final LlmService _llmService = LlmService();
  final Dio _dio = Dio();

  bool _isLlmInitialized = false;
  bool _isDownloading = false;
  bool _isPreparing = true;
  double _downloadProgress = 0.0;
  String _downloadStatusText = 'Preparando espacio local...';
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _initializeLlm();
  }

  Future<void> _initializeLlm() async {
    if (mounted) {
      setState(() {
        _isPreparing = true;
        _downloadError = null;
      });
    }

    try {
      final modelFile = await _getModelFile();
      final tempFile = File('${modelFile.path}.download');

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (await modelFile.exists()) {
        final initialized = await _tryInitModel(modelFile.path);
        if (initialized) {
          return;
        }

        await modelFile.delete();
      }

      await _downloadAndInitialize(modelFile, tempFile);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadError = 'No fue posible preparar la IA: $error';
        _isPreparing = false;
        _isDownloading = false;
      });
    }
  }

  Future<File> _getModelFile() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${supportDir.path}/ai_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    return File('${modelDir.path}/$_modelFileName');
  }

  Future<bool> _tryInitModel(String path) async {
    _llmService.setModelType('qwen');
    final success = await _llmService.initLlm(path);

    if (!mounted) {
      return success;
    }

    setState(() {
      _isLlmInitialized = success;
      _isPreparing = false;
      _isDownloading = false;
      _downloadError = success ? null : 'El modelo existe pero no pudo abrirse.';
      _downloadStatusText = success
          ? 'IA local lista para trabajar.'
          : 'No fue posible inicializar el modelo local.';
    });

    return success;
  }

  Future<void> _downloadAndInitialize(File targetFile, File tempFile) async {
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _isLlmInitialized = false;
        _downloadProgress = 0;
        _downloadError = null;
        _downloadStatusText = 'Descargando modelo local...';
      });
    }

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    await _dio.download(
      _modelUrl,
      tempFile.path,
      deleteOnError: true,
      options: Options(
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(minutes: 2),
      ),
      onReceiveProgress: (received, total) {
        if (!mounted || total <= 0) {
          return;
        }

        setState(() {
          _downloadProgress = received / total;
          _downloadStatusText =
              'Descargando modelo... ${(received / 1024 / 1024).toStringAsFixed(0)} MB / ${(total / 1024 / 1024).toStringAsFixed(0)} MB';
        });
      },
    );

    if (!await tempFile.exists()) {
      throw Exception('La descarga no genero un archivo temporal valido.');
    }

    final tempBytes = await tempFile.length();
    if (tempBytes < 1024 * 1024) {
      await tempFile.delete();
      throw Exception('El archivo descargado es demasiado pequeno para ser valido.');
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);

    if (!mounted) {
      return;
    }
    setState(() => _downloadStatusText = 'Inicializando IA local...');

    final initialized = await _tryInitModel(targetFile.path);
    if (!initialized) {
      throw Exception('La descarga termino pero el modelo no pudo inicializarse.');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.sand),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isLlmInitialized
                            ? AppColors.sage
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _isLlmInitialized
                            ? Icons.memory_rounded
                            : Icons.cloud_download_rounded,
                        color: AppColors.soil,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asistente local de campo',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _downloadStatusText,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _isLlmInitialized
                            ? AppColors.success
                            : (_downloadError != null
                                ? AppColors.danger
                                : AppColors.clayStrong),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Consumer<TaskProvider>(
                builder: (context, provider, child) {
                  final tasks = provider.tasks;
                  if (tasks.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Todavia no hay tareas registradas. Cuando la IA este lista, puedes empezar a capturar actividades del campo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 17,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Dismissible(
                        key: Key(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await provider.removeTask(task.id);
                          _showSnackBar(
                            'Tarea "${task.title}" eliminada.',
                            AppColors.danger,
                          );
                        },
                        child: _TaskCard(task: task),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    if (_isDownloading || _isPreparing || _downloadError != null) {
      return _ModelStatusCard(
        isDownloading: _isDownloading,
        isError: _downloadError != null,
        progress: _downloadProgress,
        status: _downloadError ?? _downloadStatusText,
        onRetry: _downloadError == null ? null : _initializeLlm,
      );
    }

    if (!_isLlmInitialized) {
      return _ModelStatusCard(
        isDownloading: false,
        isError: true,
        progress: 0,
        status: 'La IA local aun no esta disponible.',
        onRetry: _initializeLlm,
      );
    }

    return AiChatBlock(llmService: _llmService);
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final AppTask task;

  @override
  Widget build(BuildContext context) {
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
            task.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            task.details,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  task.category,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat('dd MMM, HH:mm').format(task.dueDate),
                style: const TextStyle(
                  color: AppColors.moss,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (task.subActivities.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...task.subActivities.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          item.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 16,
                          color: item.isCompleted
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: item.isCompleted
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ModelStatusCard extends StatelessWidget {
  const _ModelStatusCard({
    required this.isDownloading,
    required this.isError,
    required this.progress,
    required this.status,
    this.onRetry,
  });

  final bool isDownloading;
  final bool isError;
  final double progress;
  final String status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : (isDownloading
                    ? Icons.cloud_download_rounded
                    : Icons.memory_rounded),
            size: 34,
            color: isError ? AppColors.danger : AppColors.moss,
          ),
          const SizedBox(height: 14),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (isDownloading) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: AppColors.surfaceMuted,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.moss),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.clayStrong,
                foregroundColor: AppColors.surface,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
