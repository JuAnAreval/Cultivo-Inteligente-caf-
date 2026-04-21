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

    final safeCommand = normalizedCommand.length > 320
        ? normalizedCommand.substring(0, 320)
        : normalizedCommand;

    final rules = '''
Eres un asistente experto en registro agricola de cafe.
Analiza SOLO actividades de campo del lote "$lotName" en la finca "$farmName".

REGLAS ESTRICTAS:
1. Responde EXCLUSIVAMENTE JSON puro.
2. Si el texto no describe una actividad agricola valida, responde exactamente:
{"error":"No se detecto una actividad de campo valida."}
3. "fecha": formato YYYY-MM-DD. Si falta, usa "$today".
4. "actividad": nombre corto, tecnico y claro de la labor realizada.
5. "aplicaciones": productos o mezclas mencionadas. Si no hay, "".
6. "dosis": cantidades mencionadas. Si no hay, "".
7. "observaciones_responsable": observaciones y/o responsable. Si no hay, "".
8. NO inventes informacion.
9. NO expliques nada fuera del JSON.

Formato obligatorio:
{
  "fecha": "$today",
  "actividad": "",
  "aplicaciones": "",
  "dosis": "",
  "observaciones_responsable": ""
}
''';

    final result =
        await _llmService.processWithRules(rules: rules, command: safeCommand);

    if (result == null) {
      return _fallbackDraft(
        normalizedCommand: normalizedCommand,
        today: today,
      );
    }

    if (result.containsKey('error')) {
      return {
        'error': (result['error'] ?? 'No se detecto una actividad valida.')
            .toString(),
      };
    }

    if (!_isValidDraft(result, normalizedCommand)) {
      return _fallbackDraft(
            normalizedCommand: normalizedCommand,
            today: today,
          ) ??
          {
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

  Map<String, dynamic>? _fallbackDraft({
    required String normalizedCommand,
    required String today,
  }) {
    final actividad = _detectActivity(normalizedCommand);
    if (actividad.isEmpty) {
      return null;
    }

    return {
      'fecha': _extractDate(normalizedCommand) ?? today,
      'actividad': actividad,
      'aplicaciones': _extractApplications(normalizedCommand),
      'dosis': _extractDose(normalizedCommand),
      'observaciones_responsable': _extractNotesOrResponsible(normalizedCommand),
    };
  }

  String _detectActivity(String input) {
    final value = input.toLowerCase();
    if (value.contains('poda')) {
      return 'Poda';
    }
    if (value.contains('plate')) {
      return 'Plateo';
    }
    if (value.contains('fertiliz') || value.contains('abono') || value.contains('urea')) {
      return 'Fertilizacion';
    }
    if (value.contains('rieg')) {
      return 'Riego';
    }
    if (value.contains('deshier') || value.contains('desyer') || value.contains('maleza')) {
      return 'Deshierbe';
    }
    if (value.contains('fumig') ||
        value.contains('asper') ||
        value.contains('pulver') ||
        value.contains('aplic')) {
      return 'Aplicacion';
    }
    if (value.contains('cosech') || value.contains('recog')) {
      return 'Cosecha';
    }
    if (value.contains('siembr')) {
      return 'Siembra';
    }
    return '';
  }

  String? _extractDate(String input) {
    final match = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(input);
    return match?.group(0);
  }

  String _extractApplications(String input) {
    final match = RegExp(
      r'(?:aplique|aplicamos|aplico|aplicar|use|usamos|utilice|utilizamos|eche|echamos)\s+([^,.]+)',
      caseSensitive: false,
    ).firstMatch(input);
    return (match?.group(1) ?? '').trim();
  }

  String _extractDose(String input) {
    final match = RegExp(
      r'\b\d+(?:[.,]\d+)?\s*(?:litros?|l|ml|cc|kg|kilos?|gramos?|g|bultos?|sacos?)\b',
      caseSensitive: false,
    ).firstMatch(input);
    return (match?.group(0) ?? '').trim();
  }

  String _extractNotesOrResponsible(String input) {
    final responsibleMatch = RegExp(
      r'(?:responsable|responsables)\s+([^,.]+)',
      caseSensitive: false,
    ).firstMatch(input);
    if (responsibleMatch != null) {
      return responsibleMatch.group(1)?.trim() ?? '';
    }

    final noteMatch = RegExp(
      r'(?:observacion|observaciones|nota|notas)\s*[:\-]?\s*([^,.]+)',
      caseSensitive: false,
    ).firstMatch(input);
    return (noteMatch?.group(1) ?? '').trim();
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
