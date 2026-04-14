import 'package:app_flutter_ai/core/services/ai/llm_service.dart';

class ActivityAiService {
  ActivityAiService(this._llmService);

  final LlmService _llmService;

  static const Set<String> _activityRoots = {
    'abon',
    'aplic',
    'asper',
    'cosech',
    'deshier',
    'desyer',
    'enmiend',
    'fertil',
    'fumig',
    'herbic',
    'insect',
    'limpie',
    'maleza',
    'poda',
    'plate',
    'plaga',
    'pulver',
    'recog',
    'reg',
    'rieg',
    'rocer',
    'siembr',
    'surco',
    'urea',
    'zoca',
  };

  static const Set<String> _invalidValues = {
    '',
    'actividad',
    'registro',
    'general',
    'varios',
    'ninguna',
    'no aplica',
    'n/a',
    'na',
  };

  Future<Map<String, dynamic>?> generateDraft({
    required String command,
    required String lotName,
    required String farmName,
  }) async {
    final normalizedCommand = command.trim();
    final today = DateTime.now().toIso8601String().split('T').first;

    if (!_looksLikeFieldActivity(normalizedCommand)) {
      return {
        'error':
            'No detecte una actividad de campo valida. Describe labores como poda, fertilizacion, riego, aplicaciones o deshierbe.',
      };
    }

    final safeCommand = normalizedCommand.length > 280
        ? normalizedCommand.substring(0, 280)
        : normalizedCommand;

    final rules = '''
Extrae una actividad caficultora del lote "$lotName" de la finca "$farmName".

Responde solo JSON puro.
Si el texto no describe una actividad agricola valida, responde:
{"error":"No se detecto una actividad de campo valida."}

Usa este formato exacto:
{
  "fecha": "$today",
  "actividad": "",
  "aplicaciones": "",
  "dosis": "",
  "observaciones_responsable": ""
}

Reglas:
- fecha: YYYY-MM-DD. Si falta, usa $today.
- actividad: titulo corto y tecnico.
- aplicaciones: productos o insumos mencionados. Si no hay, "".
- dosis: cantidades mencionadas. Si no hay, "".
- observaciones_responsable: observaciones (puede que existan o no, si no menciona nada no agregar nada, unicamente el responsable) o responsable. Si no hay, "".
- No inventes datos.
- No expliques nada.
''';

    final result =
        await _llmService.processWithRules(rules: rules, command: safeCommand);

    if (result == null) {
      return null;
    }

    if (result.containsKey('error')) {
      return {
        'error': (result['error'] ?? 'No se detecto una actividad valida.')
            .toString(),
      };
    }

    if (!_isValidDraft(result, normalizedCommand)) {
      return {
        'error':
            'Ese mensaje no parece una actividad de campo valida para registrar.',
      };
    }

    return {
      'fecha': (result['fecha'] ?? today).toString().trim(),
      'actividad': _capitalize((result['actividad'] ?? '').toString().trim()),
      'aplicaciones': (result['aplicaciones'] ?? '').toString().trim(),
      'dosis': (result['dosis'] ?? '').toString().trim(),
      'observaciones_responsable':
          (result['observaciones_responsable'] ?? '').toString().trim(),
    };
  }

  bool _looksLikeFieldActivity(String input) {
    final normalized = input.toLowerCase();
    if (normalized.length > 35) {
      return true;
    }
    return _activityRoots.any((root) => normalized.contains(root));
  }

  bool _isValidDraft(Map<String, dynamic> draft, String originalCommand) {
    final activity = (draft['actividad'] ?? '').toString().toLowerCase().trim();
    final fecha = (draft['fecha'] ?? '').toString().trim();

    if (fecha.isEmpty || activity.isEmpty) {
      return false;
    }

    if (_invalidValues.contains(activity) || activity.length < 3) {
      return false;
    }

    if (!_looksLikeFieldActivity(originalCommand) &&
        !_looksLikeFieldActivity(activity)) {
      return false;
    }

    return true;
  }

  String _capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text[0].toUpperCase() + text.substring(1);
  }
}
