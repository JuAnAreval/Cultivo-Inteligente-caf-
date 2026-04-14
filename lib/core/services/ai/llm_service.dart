import 'dart:convert';

import 'package:flutter/services.dart';

class LlmService {
  static const MethodChannel _channel = MethodChannel('com.appflutterai/llm');

  String _currentModelType = 'qwen';

  Future<bool> initLlm(String modelPath) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'initLlm',
        {'modelPath': modelPath},
      );
      return result == 'Initialized';
    } on PlatformException catch (error) {
      print("Failed to init LLM: '${error.message}'.");
      return false;
    }
  }

  void setModelType(String type) {
    _currentModelType = type;
  }

  Future<Map<String, dynamic>?> processCommand(String command) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final rules = '''
Eres un experto en gestion y productividad. Mapea la orden del usuario a JSON aplicando estas reglas estrictas:
1. "title": maximo 5 palabras y en formato titulo.
2. "details": conserva el texto original completo, sin omitir ni resumir.
3. "subActivities": inventa obligatoriamente 3 pasos logicos, creativos y detallados.
4. "category": una sola palabra y estrictamente en espanol.
5. Fechas e ISO8601: extrae la hora exacta asumiendo que hoy es $today. Si no da fecha, usa las 18:00:00 de hoy.
6. No uses Markdown. Devuelve exclusivamente JSON puro.

Formato requerido:
{
  "title": "[Titulo Corto]",
  "state": "pending",
  "color": "#42A5F5",
  "category": "[Categoria En Espanol]",
  "details": "[Texto completo intacto]",
  "dueDate": "${today}T18:00:00",
  "subActivities": [
    {"title": "[Paso 1]", "date": "${today}T10:00:00"},
    {"title": "[Paso 2]", "date": "${today}T12:00:00"},
    {"title": "[Paso 3]", "date": "${today}T18:00:00"}
  ]
}
''';

    return processWithRules(rules: rules, command: command);
  }

  Future<Map<String, dynamic>?> processWithRules({
    required String rules,
    required String command,
  }) async {
    final prompt = _buildPrompt(rules, command);

    try {
      final response = await _channel.invokeMethod<String>(
        'generateResponse',
        {'prompt': prompt},
      );

      final jsonString = _extractJsonObject(response);
      if (jsonString == null) {
        return null;
      }

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (error) {
      print('Failed to generate response: $error');
      return null;
    }
  }

  String _buildPrompt(String rules, String command) {
    if (_currentModelType == 'qwen' || _currentModelType == 'deepseek') {
      return '''
<|im_start|>system
$rules<|im_end|>
<|im_start|>user
Texto exacto a convertir: "$command"
Muestra solamente el JSON.
<|im_end|>
<|im_start|>assistant
''';
    }

    return '''
<start_of_turn>user
$rules
Texto exacto a convertir: "$command"
Muestra solamente el JSON.
<end_of_turn>
<start_of_turn>model
''';
  }

  String? _extractJsonObject(String? response) {
    if (response == null) {
      return null;
    }

    final startIndex = response.indexOf('{');
    final endIndex = response.lastIndexOf('}');
    if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
      return null;
    }

    return response.substring(startIndex, endIndex + 1);
  }
}
