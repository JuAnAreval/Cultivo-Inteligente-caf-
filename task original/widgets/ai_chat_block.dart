import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../services/llm_service.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';

class AiChatBlock extends StatefulWidget {
  final LlmService llmService;

  const AiChatBlock({Key? key, required this.llmService}) : super(key: key);

  @override
  _AiChatBlockState createState() => _AiChatBlockState();
}

class _AiChatBlockState extends State<AiChatBlock> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;

  void _listen() async {
    if (!_isListening) {
      // Guardar lo que ya estaba escrito o dictado antes de prender el mic
      final String previousText = _controller.text;

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
             setState(() => _isListening = false);
          }
        },
        onError: (val) => print('onError: \$val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            // Unir el texto viejo con el nuevo dictado en tiempo real
            _controller.text = previousText.isEmpty 
                ? val.recognizedWords 
                : previousText + ' ' + val.recognizedWords;
            // Forzar el Scroll arrastrando el cursor virtual hasta la ultima letra disponible
            _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
          }),
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(seconds: 10),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      // Ya NO se envía automáticamente. El usuario decidirá cuándo presionar 'Send'.
    }
  }

  Future<void> _processCommand(String text) async {
    if (text.isEmpty) return;
    
    print('\n🚀 NUEVA TAREA DETECTADA EN UI: "' + text + '"');
    
    setState(() {
      _isProcessing = true;
      _controller.clear();
    });

    try {
      final jsonResult = await widget.llmService.processCommand(text);
      if (jsonResult != null) {
        final task = AppTask.fromJson(jsonResult);
        Provider.of<TaskProvider>(context, listen: false).addTask(task);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Actividad agregada: "' + task.title + '"!', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'CERRAR', textColor: Colors.black87, onPressed: () {}),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comando no comprendido por la IA. Intenta de nuevo.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'CERRAR', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de procesamiento: ' + e.toString(), style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'CERRAR', textColor: Colors.white, onPressed: () {}),
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isProcessing ? 'AI esta pensando...' : 'Escriba o dicte una tarea...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _processCommand,
                    enabled: !_isProcessing,
                  ),
                ),
              ),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color: _isListening ? Colors.redAccent : Colors.white,
                  onPressed: _listen,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () => _processCommand(_controller.text),
                ),
              ]
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: '💡 Pro-Tip de Dictado: ',
                  style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text: '"[Actividad] para [Día/Fecha]. Pasos: Primero, [Paso 1] a las [Hora 1]. Luego, [Paso 2] a las [Hora 2]..." Puedes prender el microfono varias veces o escribir y dictar en el campo de texto',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
