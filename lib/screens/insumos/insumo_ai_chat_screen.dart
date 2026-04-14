import 'dart:io';

import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/ai/llm_service.dart';
import 'package:app_flutter_ai/core/services/insumos/insumo_ai_service.dart';
import 'package:app_flutter_ai/core/services/insumos/insumo_servies.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class InsumoAiChatScreen extends StatefulWidget {
  const InsumoAiChatScreen({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.farmName,
  });

  final String lotId;
  final String lotName;
  final String farmName;

  @override
  State<InsumoAiChatScreen> createState() => _InsumoAiChatScreenState();
}

class _InsumoAiChatScreenState extends State<InsumoAiChatScreen> {
  static const String _modelFileName = 'qwen_2_5_1_5b.task';
  static const String _modelUrl =
      'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _insumoController = TextEditingController();
  final TextEditingController _ingredientesController =
      TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _facturaController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final LlmService _llmService = LlmService();
  final Dio _dio = Dio();

  late final InsumoAiService _insumoAiService = InsumoAiService(_llmService);

  final List<_ChatMessage> _messages = [];

  String _tipo = 'organico';
  String _origen = 'propio';
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
    _messageController.dispose();
    _insumoController.dispose();
    _ingredientesController.dispose();
    _fechaController.dispose();
    _facturaController.dispose();
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
      _errorText = success ? null : 'No se pudo abrir el modelo local.';
      _statusText =
          success ? 'IA lista para registrar insumos.' : 'IA no disponible.';
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
      throw Exception('La descarga no genero un archivo temporal valido.');
    }

    final size = await tempFile.length();
    if (size < 1024 * 1024) {
      await tempFile.delete();
      throw Exception('La descarga no es valida.');
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
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
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
        'No fue posible activar el microfono en este momento.',
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

    final draft = await _insumoAiService.generateDraft(
      command: command,
      lotName: widget.lotName,
      farmName: widget.farmName,
    );

    if (!mounted) {
      return;
    }

    if (draft == null) {
      setState(() {
        _messages.add(
          _ChatMessage.system(
            'La IA no pudo estructurar el insumo. Intenta con mas detalle.',
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
      return;
    }

    if (draft['error'] != null) {
      setState(() {
        _messages.add(_ChatMessage.system((draft['error'] ?? '').toString()));
        _isProcessing = false;
      });
      _scrollToBottom();
      return;
    }

    _insumoController.text = (draft['insumo'] ?? '').toString();
    _ingredientesController.text =
        (draft['ingredientes_activos'] ?? '').toString();
    _fechaController.text = (draft['fecha'] ?? '').toString();
    _tipo = (draft['tipo'] ?? 'organico').toString();
    _origen = (draft['origen'] ?? 'propio').toString();
    _facturaController.text = (draft['factura'] ?? '').toString();

    setState(() {
      _hasDraft = true;
      _messages.add(
        _ChatMessage.system(
          'Listo. Revise el borrador del insumo y guardelo si esta correcto.',
        ),
      );
      _isProcessing = false;
    });
    _scrollToBottom();
  }

  Future<void> _saveDraft() async {
    if (_insumoController.text.trim().isEmpty ||
        _fechaController.text.trim().isEmpty) {
      _showSnackBar(
        'Completa al menos la fecha y el nombre del insumo.',
        AppColors.danger,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await InsumoService.create({
        'id_lote': widget.lotId,
        'insumo': _insumoController.text.trim(),
        'ingredientes_activos': _ingredientesController.text.trim(),
        'fecha': _fechaController.text.trim(),
        'tipo': _tipo,
        'origen': _origen,
        'factura': _facturaController.text.trim(),
      });

      if (!mounted) {
        return;
      }

      _showSnackBar('Insumo guardado correctamente.', AppColors.success);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('No se pudo guardar el insumo: $error', AppColors.danger);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
 
  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isBlocked = _isDownloading || _isPreparing || _errorText != null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Chat IA - ${widget.lotName}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _CompactHeaderCard(
                  farmName: widget.farmName,
                  lotName: widget.lotName,
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
                  if (_messages.isEmpty) const _IntroCard(),
                  ..._messages.map((message) => _ChatBubble(message: message)),
                  if (_hasDraft) ...[
                    const SizedBox(height: 12),
                    _AiDraftWrapper(
                      child: _DraftCard(
                        insumoController: _insumoController,
                        ingredientesController: _ingredientesController,
                        fechaController: _fechaController,
                        facturaController: _facturaController,
                        tipo: _tipo,
                        origen: _origen,
                        onTipoChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _tipo = value);
                        },
                        onOrigenChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _origen = value);
                        },
                        onSave: _isSaving ? null : _saveDraft,
                        isSaving: _isSaving,
                      ),
                    ),
                  ],
                ],
                SizedBox(
                  height: viewInsets > 0 ? 12 : 88 + bottomSafeArea,
                ),
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
              child: _ComposerCard(
                controller: _messageController,
                isListening: _isListening,
                isProcessing: _isProcessing,
                onListen: _listen,
                onSend: _sendMessage,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactHeaderCard extends StatelessWidget {
  const _CompactHeaderCard({
    required this.farmName,
    required this.lotName,
  });

  final String farmName;
  final String lotName;

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
          Text(
            'Lote $lotName',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Describe el insumo y la IA te devuelve un borrador editable.',
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
                  hintText: 'Describe el insumo...',
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
                ),
                icon: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: isListening
                      ? AppColors.danger
                      : AppColors.textSecondary,
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

class _IntroCard extends StatelessWidget {
  const _IntroCard();

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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ejemplos rapidos',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Aplique abono organico bocashi hoy en la tarde, ingredientes gallinaza y melaza, fue propio.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          SizedBox(height: 8),
          Text(
            'Compre fungicida score para el lote, ingrediente activo difenoconazol, factura 12345.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
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
    required this.insumoController,
    required this.ingredientesController,
    required this.fechaController,
    required this.facturaController,
    required this.tipo,
    required this.origen,
    required this.onTipoChanged,
    required this.onOrigenChanged,
    required this.onSave,
    required this.isSaving,
  });

  final TextEditingController insumoController;
  final TextEditingController ingredientesController;
  final TextEditingController fechaController;
  final TextEditingController facturaController;
  final String tipo;
  final String origen;
  final ValueChanged<String?> onTipoChanged;
  final ValueChanged<String?> onOrigenChanged;
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
            label: 'Insumo',
            controller: insumoController,
            hint: 'Nombre del insumo',
          ),
          const SizedBox(height: 12),
          _DraftField(
            label: 'Ingredientes activos',
            controller: ingredientesController,
            hint: 'Composicion o referencia',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _DraftField(
            label: 'Fecha',
            controller: fechaController,
            hint: 'YYYY-MM-DD',
          ),
          const SizedBox(height: 12),
          _DropdownField(
            label: 'Tipo',
            value: tipo,
            items: const [
              DropdownMenuItem(value: 'organico', child: Text('Organico')),
              DropdownMenuItem(
                value: 'convencional',
                child: Text('Convencional'),
              ),
            ],
            onChanged: onTipoChanged,
          ),
          const SizedBox(height: 12),
          _DropdownField(
            label: 'Origen',
            value: origen,
            items: const [
              DropdownMenuItem(value: 'propio', child: Text('Propio')),
              DropdownMenuItem(value: 'comprado', child: Text('Comprado')),
            ],
            onChanged: onOrigenChanged,
          ),
          const SizedBox(height: 12),
          _DraftField(
            label: 'Factura',
            controller: facturaController,
            hint: 'Numero o referencia',
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
              label: Text(isSaving ? 'Guardando...' : 'Guardar insumo'),
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
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

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
          maxLines: maxLines,
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
