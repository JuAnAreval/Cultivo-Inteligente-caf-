import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/models/task_model.dart';
import 'package:app_flutter_ai/core/providers/task_provider.dart';
import 'package:app_flutter_ai/core/services/llm_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiChatBlock extends StatefulWidget {
  const AiChatBlock({super.key, required this.llmService});

  final LlmService llmService;

  @override
  State<AiChatBlock> createState() => _AiChatBlockState();
}

class _AiChatBlockState extends State<AiChatBlock> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isProcessing = false;

  Future<void> _listen() async {
    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      return;
    }

    final previousText = _controller.text;
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) => print('onError: $error'),
    );

    if (!available) {
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) => setState(() {
        _controller.text = previousText.isEmpty
            ? result.recognizedWords
            : '$previousText ${result.recognizedWords}';
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }),
      pauseFor: const Duration(seconds: 10),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _processCommand(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final jsonResult = await widget.llmService.processCommand(trimmed);
      if (!mounted) {
        return;
      }

      if (jsonResult == null) {
        _showSnackBar(
          message: 'La IA no pudo estructurar esta orden. Intenta con mas detalle.',
          background: AppColors.danger,
          textColor: Colors.white,
        );
        return;
      }

      final task = AppTask.fromJson(jsonResult);
      await Provider.of<TaskProvider>(context, listen: false).addTask(task);
      _controller.clear();

      if (!mounted) {
        return;
      }

      _showSnackBar(
        message: 'Actividad agregada: "${task.title}"',
        background: AppColors.success,
        textColor: AppColors.surface,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        message: 'Error de procesamiento: $error',
        background: AppColors.clayStrong,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSnackBar({
    required String message,
    required Color background,
    required Color textColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'CERRAR',
          textColor: textColor,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0x145F4C3F),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: AppColors.sand,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: TextField(
                    controller: _controller,
                    scrollController: _scrollController,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _isProcessing
                          ? 'La IA esta pensando...'
                          : 'Escribe o dicta una tarea...',
                      hintStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _processCommand,
                    enabled: !_isProcessing,
                  ),
                ),
              ),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.moss,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color:
                      _isListening ? AppColors.danger : AppColors.textSecondary,
                  onPressed: _listen,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.moss),
                  onPressed: () => _processCommand(_controller.text),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Tip de dictado: ',
                  style: TextStyle(
                    color: AppColors.soil,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                TextSpan(
                  text:
                      '"[Actividad] para [dia o fecha]. Pasos: primero [paso 1] a las [hora]. Luego [paso 2]..." Puedes alternar entre escribir y dictar sin perder el texto.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
