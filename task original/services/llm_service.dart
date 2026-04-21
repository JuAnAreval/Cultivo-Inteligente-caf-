import 'dart:convert';
import 'package:flutter/services.dart';

class LlmService {
  static const MethodChannel _channel = MethodChannel('com.appflutterai/llm');

  Future<bool> initLlm(String modelPath) async {
    try {
      final result = await _channel.invokeMethod<String>('initLlm', {'modelPath': modelPath});
      return result == 'Initialized';
    } on PlatformException catch (e) {
      print("Failed to init LLM: '${e.message}'.");
      return false;
    }
  }

  String _currentModelType = 'qwen'; // 'qwen', 'deepseek', 'gemma'

  void setModelType(String type) {
    _currentModelType = type;
  }

  Future<Map<String, dynamic>?> processCommand(String command) async {
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    
    // Configuración paramétrica para Qwen 2.5 1.5B (Alto razonamiento y JSON Estricto)
    final reglas = '''Eres un experto en gestión y productividad. Mapea la orden del usuario a JSON aplicando estas REGLAS ESTRICTAS:
1. "title": MÁXIMO 5 PALABRAS. Aplica "Formato Título" (Todas Las Palabras Tienen Inicial Mayúscula).
2. "details": DEBES devolver exactamente la orden original completa, sin omitir ni resumir absolutamente NINGUNA palabra del usuario. Solo estructúralo como un párrafo gramaticalmente impecable empezando con mayúscula.
3. "subActivities": INVENTA obligatoriamente 3 pasos lógicos, creativos y detallados (Ej: "Contactar a proveedores").
4. "category": Asigna la categoría en una sola palabra estricta y EXCLUSIVAMENTE EN ESPAÑOL (Ej. Trabajo, Personal, Viaje, Compras).
5. Fechas e ISO8601: Extrae la HORA exacta asumiendo que hoy es: ''' + dateStr + '''. Si no da fecha, asume las 18:00:00 de hoy.
6. NO uses etiquetas Markdown. Devuelve EXCLUSIVAMENTE el texto del JSON puro.

Formato requerido estricto:
{
  "title": "[Formato De Título Corto]",
  "state": "pending",
  "color": "#42A5F5",
  "category": "[Categoría En Español]",
  "details": "[Texto completo intacto 100% preservado sin resumir, con Mayúscula inicial]",
  "dueDate": "''' + dateStr + '''T18:00:00",
  "subActivities": [
    {"title": "[Paso altamente creativo 1]", "date": "''' + dateStr + '''T10:00:00"},
    {"title": "[Paso altamente creativo 2]", "date": "''' + dateStr + '''T12:00:00"},
    {"title": "[Paso altamente creativo 3]", "date": "''' + dateStr + '''T18:00:00"}
  ]
}''';

    // Inyección de esquema dinámico (ChatML vs Gemma)
    String prompt;
    if (_currentModelType == 'qwen' || _currentModelType == 'deepseek') {
        prompt = '''<|im_start|>system\n''' + reglas + '''<|im_end|>
<|im_start|>user
Texto exacto a convertir: "''' + command + '''"
Muestra SOLAMENTE el JSON.<|im_end|>
<|im_start|>assistant\n''';
    } else {
        prompt = '''<start_of_turn>user\n''' + reglas + '''\n
Texto exacto a convertir: "''' + command + '''"
Muestra SOLAMENTE el JSON.
<end_of_turn>
<start_of_turn>model\n''';
    }

    print('\n===== [1. ENVIANDO A LA IA (' + _currentModelType + ')] =====');
    print('Comando detectado: "' + command + '"');

    try {
      final response = await _channel.invokeMethod<String>('generateResponse', {'prompt': prompt});
      
      print('\n===== [2. RESPUESTA CRUDA DE LA IA] =====');
      print(response);
      print('====================================');
      
      if (response != null) {
        // Extracción robusta (Ignora los bloques <think> de DeepSeek R1)
        final int startIndex = response.indexOf('{');
        final int endIndex = response.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
            final jsonString = response.substring(startIndex, endIndex + 1);
            return jsonDecode(jsonString);
        }
      }
    } catch (e) {
      print('Failed to generate response: $e');
    }
    return null;
  }
}
