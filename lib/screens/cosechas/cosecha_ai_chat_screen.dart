import 'dart:io';

import 'package:app_flutter_ai/core/config/ai_model_config.dart';
import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/ai/llm_service.dart';
import 'package:app_flutter_ai/core/services/cosechas/cosecha_ai_service.dart';
import 'package:app_flutter_ai/core/services/cosechas/cosecha_service.dart';
import 'package:app_flutter_ai/core/widgets/cultiva_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CosechaAiChatScreen extends StatefulWidget {
  const CosechaAiChatScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  final String farmId;
  final String farmName;

  @override
  State<CosechaAiChatScreen> createState() => _CosechaAiChatScreenState();
}

class _CosechaAiChatScreenState extends State<CosechaAiChatScreen> {
  static const String _modelFileName = AiModelConfig.modelFileName;
  static const String _modelUrl = AiModelConfig.modelUrl;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _kilosCerezaController = TextEditingController();
  final TextEditingController _kilosPergaminoController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final LlmService _llmService = LlmService();
  final Dio _dio = Dio();

  late final CosechaAiService _cosechaAiService = CosechaAiService(_llmService);

  final List<_ChatMessage> _messages = [];
  final List<String> _quickSuggestions = const [
    'Hoy recolectamos 320 kilos de cereza y 72 de pergamino, proceso lavado.',
    'Registra una cosecha de 180 kilos de cereza y 45 de pergamino del día de hoy, proceso miel.',
    'Ayer hubo cosecha natural con 210 kilos de cereza y 50 de pergamino.',
  ];

  String _proceso = '';
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _hasDraft = false;
  bool _isLlmInitialized = false;
  bool _isDownloading = false;
  bool _isPreparing = true;
  double _downloadProgress = 0;
  String _statusText = 'Preparando IA local...';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _initializeLlm();
  }

  @override
  void dispose() {
    _speech.stop();
    _messageController.dispose();
    _fechaController.dispose();
    _kilosCerezaController.dispose();
    _kilosPergaminoController.dispose();
    _scrollController.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _initializeLlm() async {
    if (mounted) {
      setState(() {
        _isPreparing = true;
        _errorText = null;
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
        _errorText = 'No fue posible preparar la IA: $error';
        _isPreparing = false;
        _isDownloading = false;
      });
    }
  }

  Future<File> _getModelFile() async {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      return File('${externalDir.path}/$_modelFileName');
    }

    final supportDir = await getApplicationSupportDirectory();
    return File('${supportDir.path}/$_modelFileName');
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
      _errorText = success ? null : 'No se pudo abrir el modelo local.';
      _statusText =
          success ? 'IA lista para registrar cosechas.' : 'IA no disponible.';
    });

    return success;
  }

  Future<void> _downloadAndInitialize(File targetFile, File tempFile) async {
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _isLlmInitialized = false;
        _downloadProgress = 0;
        _errorText = null;
        _statusText = 'Descargando modelo local...';
      });
    }

    await _dio.download(
      _modelUrl,
      tempFile.path,
      deleteOnError: true,
      options: Options(
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(minutes: 2),
        headers: const {
          'accept': '*/*',
          'user-agent': 'app_flutter_ai/1.0',
        },
      ),
      onReceiveProgress: (received, total) {
        if (!mounted || total <= 0) {
          return;
        }
        setState(() {
          _downloadProgress = received / total;
          _statusText =
              'Descargando IA... ${(received / 1024 / 1024).toStringAsFixed(0)} MB / ${(total / 1024 / 1024).toStringAsFixed(0)} MB';
        });
      },
    );

    if (!await tempFile.exists()) {
      throw Exception('La descarga no generó un archivo temporal válido.');
    }

    final size = await tempFile.length();
    if (size < 1024 * 1024) {
      await tempFile.delete();
      throw Exception('La descarga no es válida.');
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    await tempFile.rename(targetFile.path);
    if (!mounted) {
      return;
    }
    setState(() => _statusText = 'Inicializando IA...');
    final initialized = await _tryInitModel(targetFile.path);
    if (!initialized) {
      throw Exception('La IA no pudo inicializarse.');
    }
  }

  Future<void> _listen() async {
    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      _showSnackBar(
        'No fue posible activar el micrófono en este momento.',
        AppColors.danger,
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _messageController.text = result.recognizedWords;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
      },
      pauseFor: const Duration(seconds: 8),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final command = _messageController.text.trim();
    if (command.isEmpty || _isProcessing || !_isLlmInitialized) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_ChatMessage.user(command));
      _isProcessing = true;
    });
    _messageController.clear();
    _scrollToBottom();

    Map<String, dynamic>? draft;
    try {
      draft = await _cosechaAiService.generateDraft(
        command: command,
        farmName: widget.farmName,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage.system(
            'La IA no pudo procesar este mensaje. Intenta con una descripción más corta.',
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
      return;
    }

    if (!mounted) {
      return;
    }

    if (draft == null) {
      setState(() {
        _messages.add(
          _ChatMessage.system(
            'La IA no pudo estructurar la cosecha. Intenta con más detalle.',
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
      return;
    }

    final safeDraft = draft;

    if (safeDraft['error'] != null) {
      setState(() {
        _messages.add(
          _ChatMessage.system((safeDraft['error'] ?? '').toString()),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
      return;
    }

    _fechaController.text =
        _normalizeDateText((safeDraft['fecha'] ?? '').toString());
    _kilosCerezaController.text =
        _normalizeNumberText((safeDraft['kilos_cereza'] ?? '').toString());
    _kilosPergaminoController.text =
        _normalizeNumberText((safeDraft['kilos_pergamino'] ?? '').toString());
    _proceso = _normalizeProceso((safeDraft['proceso'] ?? '').toString());

    setState(() {
      _hasDraft = true;
      _messages.add(
        _ChatMessage.system(
          'Listo. Revisa el borrador de cosecha y guárdalo si está correcto.',
        ),
      );
      _isProcessing = false;
    });
    _scrollToBottom();
  }

  Future<void> _saveDraft() async {
    final formattedDate = _normalizeDateText(_fechaController.text.trim());
    final kilosCereza =
        _normalizeNumberText(_kilosCerezaController.text.trim());
    final kilosPergamino = _normalizeNumberText(
      _kilosPergaminoController.text.trim(),
    );

    if (!_isCurrentYearDate(formattedDate)) {
      _showSnackBar(
        'La fecha debe tener formato YYYY-MM-DD y ser del año actual.',
        AppColors.danger,
      );
      return;
    }

    if (kilosCereza.isEmpty || kilosPergamino.isEmpty) {
      _showSnackBar(
        'Completa los kilos de cereza y de pergamino.',
        AppColors.danger,
      );
      return;
    }

    if (_parseNumber(kilosCereza) == null ||
        _parseNumber(kilosPergamino) == null) {
      _showSnackBar(
        'Los kilos deben ser números válidos.',
        AppColors.danger,
      );
      return;
    }

    if ((_parseNumber(kilosCereza) ?? 0) < 0 ||
        (_parseNumber(kilosPergamino) ?? 0) < 0) {
      _showSnackBar(
        'Los kilos no pueden ser negativos.',
        AppColors.danger,
      );
      return;
    }

    if (_normalizeProceso(_proceso).isEmpty) {
      _showSnackBar(
        'Selecciona el proceso de la cosecha.',
        AppColors.danger,
      );
      return;
    }

    _fechaController.text = formattedDate;
    _kilosCerezaController.text = kilosCereza;
    _kilosPergaminoController.text = kilosPergamino;
    _proceso = _normalizeProceso(_proceso);

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await CosechaService.create({
        'id_finca': widget.farmId,
        'fecha': formattedDate,
        'kilos_cereza': _parseNumber(kilosCereza),
        'kilos_pergamino': _parseNumber(kilosPergamino),
        'proceso': _proceso,
        'anio': _extractYear(formattedDate),
      });

      if (!mounted) {
        return;
      }

      _showSnackBar('Cosecha guardada correctamente.', AppColors.success);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('No se pudo guardar la cosecha: $error', AppColors.danger);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _applySuggestion(String suggestion) {
    _messageController.text = suggestion;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  String _normalizeDateText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final isoMatch = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(trimmed);
    if (isoMatch != null) {
      return isoMatch.group(0) ?? '';
    }

    final slashMatch =
        RegExp(r'\b(\d{4})/(\d{2})/(\d{2})\b').firstMatch(trimmed);
    if (slashMatch != null) {
      return '${slashMatch.group(1)}-${slashMatch.group(2)}-${slashMatch.group(3)}';
    }

    return trimmed;
  }

  String _normalizeNumberText(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return '';
    }

    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      return normalized;
    }

    return parsed == parsed.truncateToDouble()
        ? parsed.toInt().toString()
        : parsed.toString();
  }

  String _normalizeProceso(String value) {
    switch (value.trim().toUpperCase()) {
      case 'MIEL':
      case 'NATURAL':
      case 'LAVADO':
        return value.trim().toUpperCase();
      default:
        return '';
    }
  }

  bool _isCurrentYearDate(String value) {
    final normalized = _normalizeDateText(value);
    final parts = normalized.split('-');
    if (parts.length != 3) {
      return false;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return false;
    }

    if (year != DateTime.now().year) {
      return false;
    }

    final parsed = DateTime.tryParse(normalized);
    return parsed != null &&
        parsed.year == year &&
        parsed.month == month &&
        parsed.day == day;
  }

  double? _parseNumber(String value) {
    return double.tryParse(value.replaceAll(',', '.'));
  }

  int _extractYear(String formattedDate) {
    return int.tryParse(formattedDate.split('-').first) ?? DateTime.now().year;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmExitIfNeeded() async {
    if (!_hasDraft) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Estás seguro de salir?'),
          content: const Text(
            'Si sales ahora, se borrará el borrador generado por la IA y tendrás que volver a llenar la información.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Seguir aquí'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.clayStrong,
                foregroundColor: AppColors.surface,
              ),
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );

    return shouldLeave ?? false;
  }

  Future<void> _handleExit() async {
    final shouldLeave = await _confirmExitIfNeeded();
    if (!mounted || !shouldLeave) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isBlocked = _isDownloading || _isPreparing || _errorText != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleExit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.background,
        appBar: buildCultivaSecondaryAppBar(
          context: context,
          title: 'Chat IA',
          leading: IconButton(
            onPressed: _handleExit,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _CompactHeaderCard(farmName: widget.farmName),
                  const SizedBox(height: 12),
                  const _RequiredDataCard(
                    title: 'Datos que necesito',
                    items: [
                      'Fecha de la cosecha',
                      'Kilos de cereza',
                      'Kilos de pergamino',
                      'Proceso, por ejemplo miel, natural o lavado',
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isBlocked)
                    _ModelStatusCard(
                      isDownloading: _isDownloading,
                      isError: _errorText != null,
                      progress: _downloadProgress,
                      status: _errorText ?? _statusText,
                      onRetry: _errorText == null ? null : _initializeLlm,
                    )
                  else ...[
                    if (_messages.isEmpty)
                      _SuggestionCard(
                        suggestions: _quickSuggestions,
                        onSelected: _applySuggestion,
                      ),
                    ..._messages
                        .map((message) => _ChatBubble(message: message)),
                    if (_hasDraft) ...[
                      const SizedBox(height: 12),
                      _AiDraftWrapper(
                        child: _DraftCard(
                          fechaController: _fechaController,
                          kilosCerezaController: _kilosCerezaController,
                          kilosPergaminoController: _kilosPergaminoController,
                          proceso: _proceso,
                          onProcesoChanged: (value) {
                            setState(() => _proceso = value ?? '');
                          },
                          onSave: _isSaving ? null : _saveDraft,
                          isSaving: _isSaving,
                        ),
                      ),
                    ],
                  ],
                  SizedBox(height: viewInsets > 0 ? 12 : 88 + bottomSafeArea),
                ],
              ),
            ),
            if (!isBlocked)
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  viewInsets > 0 ? viewInsets + 8 : bottomSafeArea + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_messages.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _quickSuggestions
                                .map(
                                  (suggestion) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _SuggestionChip(
                                      label: suggestion,
                                      onTap: () => _applySuggestion(suggestion),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _ComposerCard(
                      controller: _messageController,
                      isListening: _isListening,
                      isProcessing: _isProcessing,
                      onListen: _listen,
                      onSend: _sendMessage,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactHeaderCard extends StatelessWidget {
  const _CompactHeaderCard({required this.farmName});

  final String farmName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Registro de cosecha',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuéntame la cosecha y la IA te devuelve un borrador listo para revisar.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.controller,
    required this.isListening,
    required this.isProcessing,
    required this.onListen,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isListening;
  final bool isProcessing;
  final VoidCallback onListen;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.sand),
          boxShadow: const [
            BoxShadow(
              color: Color(0x145F4C3F),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                enabled: !isProcessing,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Describe la cosecha...',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 6),
            if (isProcessing)
              const SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    color: AppColors.moss,
                    strokeWidth: 2.2,
                  ),
                ),
              )
            else ...[
              IconButton(
                onPressed: onListen,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isListening
                      ? AppColors.danger.withValues(alpha: 0.14)
                      : AppColors.backgroundSoft,
                  side: BorderSide(
                    color: isListening
                        ? AppColors.danger.withValues(alpha: 0.35)
                        : Colors.transparent,
                  ),
                ),
                icon: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color:
                      isListening ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onSend,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.moss,
                ),
                icon: const Icon(
                  Icons.send_rounded,
                  color: AppColors.surface,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestions,
    required this.onSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sugerencias rápidas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: suggestions
                  .map(
                    (suggestion) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SuggestionChip(
                        label: suggestion,
                        onTap: () => onSelected(suggestion),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.backgroundSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.sand),
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredDataCard extends StatelessWidget {
  const _RequiredDataCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.moss,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.clayStrong : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: isUser ? null : Border.all(color: AppColors.sand),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? AppColors.surface : AppColors.textPrimary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _AiDraftWrapper extends StatelessWidget {
  const _AiDraftWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.sand),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: AppColors.moss,
              ),
              SizedBox(width: 6),
              Text(
                'Borrador generado por IA',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.fechaController,
    required this.kilosCerezaController,
    required this.kilosPergaminoController,
    required this.proceso,
    required this.onProcesoChanged,
    required this.onSave,
    required this.isSaving,
  });

  final TextEditingController fechaController;
  final TextEditingController kilosCerezaController;
  final TextEditingController kilosPergaminoController;
  final String proceso;
  final ValueChanged<String?> onProcesoChanged;
  final VoidCallback? onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Borrador editable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Corrige los campos si hace falta antes de guardar.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _DraftField(
            label: 'Fecha',
            controller: fechaController,
            hint: 'YYYY-MM-DD',
          ),
          const SizedBox(height: 12),
          _DraftField(
            label: 'Kilos cereza',
            controller: kilosCerezaController,
            hint: 'Cantidad de cereza',
          ),
          const SizedBox(height: 12),
          _DraftField(
            label: 'Kilos pergamino',
            controller: kilosPergaminoController,
            hint: 'Cantidad de pergamino',
          ),
          const SizedBox(height: 12),
          _DropdownField(
            label: 'Proceso',
            value: proceso,
            items: const [
              DropdownMenuItem(value: '', child: Text('Selecciona')),
              DropdownMenuItem(value: 'MIEL', child: Text('MIEL')),
              DropdownMenuItem(value: 'NATURAL', child: Text('NATURAL')),
              DropdownMenuItem(value: 'LAVADO', child: Text('LAVADO')),
            ],
            onChanged: onProcesoChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.moss,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(isSaving ? 'Guardando...' : 'Guardar cosecha'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftField extends StatelessWidget {
  const _DraftField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.backgroundSoft,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.surface,
          iconEnabledColor: AppColors.moss,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.backgroundSoft,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
            size: 32,
            color: isError ? AppColors.danger : AppColors.moss,
          ),
          const SizedBox(height: 12),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (isDownloading) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: AppColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.moss),
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

enum _ChatRole { user, system }

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
  });

  final _ChatRole role;
  final String text;

  factory _ChatMessage.user(String text) {
    return _ChatMessage(role: _ChatRole.user, text: text);
  }

  factory _ChatMessage.system(String text) {
    return _ChatMessage(role: _ChatRole.system, text: text);
  }
}
