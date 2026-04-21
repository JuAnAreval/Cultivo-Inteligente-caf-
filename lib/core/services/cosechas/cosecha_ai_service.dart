import 'package:app_flutter_ai/core/services/ai/llm_service.dart';

class CosechaAiService {
  CosechaAiService(this._llmService);

  final LlmService _llmService;

  static const Set<String> _harvestRoots = {
    'cosech',
    'recolect',
    'cereza',
    'pergamino',
    'benefici',
    'despulp',
    'lavado',
    'miel',
    'natural',
    'secado',
    'kilo',
    'kg',
    'arroba',
  };

  static const Set<String> _invalidValues = {
    '',
    'registro',
    'general',
    'varios',
    'ninguno',
    'no aplica',
    'n/a',
    'na',
  };

  Future<Map<String, dynamic>?> generateDraft({
    required String command,
    required String farmName,
  }) async {
    final normalizedCommand = command.trim();
    final today = DateTime.now().toIso8601String().split('T').first;
    final currentYear = DateTime.now().year.toString();

    if (!_looksLikeHarvestRecord(normalizedCommand)) {
      return {
        'error':
            'No detecte un registro de cosecha valido. Describe recoleccion, kilos de cereza o pergamino, o el proceso.',
      };
    }

    final safeCommand = normalizedCommand.length > 320
        ? normalizedCommand.substring(0, 320)
        : normalizedCommand;

    final rules = '''
Eres un asistente experto en registro de cosechas de cafe.
Analiza SOLO registros de cosecha de la finca "$farmName".

REGLAS ESTRICTAS:
1. Responde EXCLUSIVAMENTE JSON puro.
2. Si el texto no describe una cosecha valida, responde exactamente:
{"error":"No se detecto un registro de cosecha valido."}
3. "fecha": formato YYYY-MM-DD. Si falta, usa "$today".
4. "kilos_cereza": numero sin unidad. Si no hay, "".
5. "kilos_pergamino": numero sin unidad. Si no hay, "".
6. "proceso": solo "MIEL", "NATURAL" o "LAVADO". Si no se menciona, "".
7. "anio": anio numerico. Si no se menciona, usa "$currentYear".
8. NO inventes informacion.
9. NO expliques nada fuera del JSON.

Formato obligatorio:
{
  "fecha": "$today",
  "kilos_cereza": "",
  "kilos_pergamino": "",
  "proceso": "",
  "anio": "$currentYear"
}
''';

    final result =
        await _llmService.processWithRules(rules: rules, command: safeCommand);

    if (result == null) {
      return _fallbackDraft(
        normalizedCommand: normalizedCommand,
        today: today,
        currentYear: currentYear,
      );
    }

    if (result.containsKey('error')) {
      return {
        'error':
            (result['error'] ?? 'No se detecto una cosecha valida.').toString(),
      };
    }

    if (!_isValidDraft(result, normalizedCommand)) {
      return _fallbackDraft(
            normalizedCommand: normalizedCommand,
            today: today,
            currentYear: currentYear,
          ) ??
          {
            'error':
                'Ese mensaje no parece un registro de cosecha valido para guardar.',
          };
    }

    final fecha = (result['fecha'] ?? today).toString().trim();

    return {
      'fecha': fecha,
      'kilos_cereza': _normalizeNumberText(result['kilos_cereza']),
      'kilos_pergamino': _normalizeNumberText(result['kilos_pergamino']),
      'proceso': _normalizeProceso((result['proceso'] ?? '').toString()),
      'anio': _normalizeAnio(
        value: result['anio'],
        fallbackDate: fecha,
      ),
    };
  }

  bool _looksLikeHarvestRecord(String input) {
    final normalized = input.toLowerCase();
    if (normalized.length > 40) {
      return true;
    }
    return _harvestRoots.any((root) => normalized.contains(root));
  }

  Map<String, dynamic>? _fallbackDraft({
    required String normalizedCommand,
    required String today,
    required String currentYear,
  }) {
    final kilosCereza = _extractNumberFor(normalizedCommand, 'cereza');
    final kilosPergamino = _extractNumberFor(normalizedCommand, 'pergamino');
    final proceso = _detectProceso(normalizedCommand);

    if (kilosCereza.isEmpty &&
        kilosPergamino.isEmpty &&
        proceso.isEmpty &&
        !_looksLikeHarvestRecord(normalizedCommand)) {
      return null;
    }

    final fecha = _extractDate(normalizedCommand) ?? today;
    final fechaYear = fecha.split('-').isNotEmpty ? fecha.split('-').first : currentYear;
    return {
      'fecha': fecha,
      'kilos_cereza': kilosCereza,
      'kilos_pergamino': kilosPergamino,
      'proceso': proceso,
      'anio': _extractYear(normalizedCommand) ?? fechaYear,
    };
  }

  String? _extractDate(String input) {
    final match = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(input);
    return match?.group(0);
  }

  String? _extractYear(String input) {
    final match = RegExp(r'\b20\d{2}\b').firstMatch(input);
    return match?.group(0);
  }

  String _extractNumberFor(String input, String label) {
    final specific = RegExp(
      '\\b(\\d+(?:[.,]\\d+)?)\\s*(?:kg|kilos?|arrobas?)\\s*(?:de\\s*)?$label\\b',
      caseSensitive: false,
    ).firstMatch(input);
    if (specific != null) {
      return _normalizeNumberText(specific.group(1));
    }

    return '';
  }

  String _detectProceso(String input) {
    final normalized = input.toLowerCase();
    if (normalized.contains('miel')) {
      return 'MIEL';
    }
    if (normalized.contains('natural')) {
      return 'NATURAL';
    }
    if (normalized.contains('lavado')) {
      return 'LAVADO';
    }
    return '';
  }

  bool _isValidDraft(Map<String, dynamic> draft, String originalCommand) {
    final fecha = (draft['fecha'] ?? '').toString().trim();
    final kilosCereza =
        _normalizeNumberText(draft['kilos_cereza']).toString().trim();
    final kilosPergamino =
        _normalizeNumberText(draft['kilos_pergamino']).toString().trim();
    final proceso = _normalizeProceso((draft['proceso'] ?? '').toString());

    if (fecha.isEmpty) {
      return false;
    }

    if (kilosCereza.isEmpty &&
        kilosPergamino.isEmpty &&
        proceso.isEmpty &&
        !_looksLikeHarvestRecord(originalCommand)) {
      return false;
    }

    if (_invalidValues.contains(kilosCereza.toLowerCase()) ||
        _invalidValues.contains(kilosPergamino.toLowerCase())) {
      return false;
    }

    return true;
  }

  String _normalizeProceso(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'miel') {
      return 'MIEL';
    }
    if (normalized == 'natural') {
      return 'NATURAL';
    }
    if (normalized == 'lavado') {
      return 'LAVADO';
    }
    return '';
  }

  String _normalizeNumberText(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) {
      return '';
    }

    final cleaned = raw
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned;
  }

  String _normalizeAnio({
    required dynamic value,
    required String fallbackDate,
  }) {
    final raw = (value ?? '').toString().trim();
    final parsed = int.tryParse(raw);
    if (parsed != null && parsed > 2000) {
      return parsed.toString();
    }

    final dateYear = fallbackDate.split('-').first;
    if (int.tryParse(dateYear) != null) {
      return dateYear;
    }

    return DateTime.now().year.toString();
  }
}
