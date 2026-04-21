import 'package:app_flutter_ai/core/services/ai/llm_service.dart';

class InsumoAiService {
  InsumoAiService(this._llmService);

  final LlmService _llmService;

  static const Set<String> _insumoRoots = {
    'abono',
    'acido',
    'agroquim',
    'bioinsumo',
    'bulto',
    'cal',
    'caldo',
    'compost',
    'compr',
    'fertiliz',
    'fungic',
    'herbic',
    'insumo',
    'insectic',
    'micorr',
    'mineral',
    'organ',
    'producto',
    'quimic',
    'sulfato',
    'urea',
  };

  static const Set<String> _invalidValues = {
    '',
    'insumo',
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
    required String lotName,
    required String farmName,
  }) async {
    final normalizedCommand = command.trim();
    final today = DateTime.now().toIso8601String().split('T').first;

    if (!_looksLikeSupplyRecord(normalizedCommand)) {
      return {
        'error':
            'No detecte un registro de insumo valido. Describe compra, uso o aplicacion de fertilizantes, agroquimicos u otros insumos.',
      };
    }

    final safeCommand = normalizedCommand.length > 320
        ? normalizedCommand.substring(0, 320)
        : normalizedCommand;

    final rules = '''
Eres un asistente experto en registro de insumos agricolas.
Analiza SOLO registros de insumos del lote "$lotName" en la finca "$farmName".

REGLAS ESTRICTAS:
1. Responde EXCLUSIVAMENTE JSON puro.
2. Si el texto no describe un registro de insumo valido, responde exactamente:
{"error":"No se detecto un registro de insumo valido."}
3. "insumo": nombre corto del producto o insumo.
4. "ingredientes_activos": ingrediente activo, referencia o composicion. Si no hay, "".
5. "fecha": formato YYYY-MM-DD. Si falta, usa "$today".
6. "tipo": solo "organico" o "convencional".
7. "origen": solo "propio" o "comprado".
8. "factura": numero, referencia o nota. Si no hay, "".
9. NO inventes informacion.
10. NO expliques nada fuera del JSON.

Formato obligatorio:
{
  "insumo": "",
  "ingredientes_activos": "",
  "fecha": "$today",
  "tipo": "convencional",
  "origen": "comprado",
  "factura": ""
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
        'error': (result['error'] ?? 'No se detecto un insumo valido.')
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
                'Ese mensaje no parece un registro de insumo valido para guardar.',
          };
    }

    return {
      'insumo': _capitalize((result['insumo'] ?? '').toString().trim()),
      'ingredientes_activos':
          (result['ingredientes_activos'] ?? '').toString().trim(),
      'fecha': (result['fecha'] ?? today).toString().trim(),
      'tipo': _normalizeTipo((result['tipo'] ?? '').toString()),
      'origen': _normalizeOrigen((result['origen'] ?? '').toString()),
      'factura': (result['factura'] ?? '').toString().trim(),
    };
  }

  bool _looksLikeSupplyRecord(String input) {
    final normalized = input.toLowerCase();
    if (normalized.length > 35) {
      return true;
    }
    return _insumoRoots.any((root) => normalized.contains(root));
  }

  Map<String, dynamic>? _fallbackDraft({
    required String normalizedCommand,
    required String today,
  }) {
    final insumo = _extractSupplyName(normalizedCommand);
    if (insumo.isEmpty) {
      return null;
    }

    return {
      'insumo': _capitalize(insumo),
      'ingredientes_activos': _extractIngredients(normalizedCommand),
      'fecha': _extractDate(normalizedCommand) ?? today,
      'tipo': _normalizeTipo(_detectTipo(normalizedCommand)),
      'origen': _normalizeOrigen(_detectOrigen(normalizedCommand)),
      'factura': _extractFactura(normalizedCommand),
    };
  }

  String _extractSupplyName(String input) {
    final patterns = [
      RegExp(
        r'(?:compre|compramos|compro|aplique|aplicamos|aplico|use|usamos|utilice|utilizamos)\s+([^,.]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(abono|urea|caldo mineral|fertilizante|fungicida|herbicida|insecticida|compost|cal|sulfato)\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        return (match.group(1) ?? '').trim();
      }
    }

    return '';
  }

  String _extractIngredients(String input) {
    final match = RegExp(
      r'(?:ingredientes?\s+activos?|ingrediente\s+activo|compuesto\s+por)\s*[:\-]?\s*([^,.]+)',
      caseSensitive: false,
    ).firstMatch(input);
    return (match?.group(1) ?? '').trim();
  }

  String? _extractDate(String input) {
    final match = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(input);
    return match?.group(0);
  }

  String _detectTipo(String input) {
    final normalized = input.toLowerCase();
    if (normalized.contains('organico') || normalized.contains('orgánico')) {
      return 'organico';
    }
    return 'convencional';
  }

  String _detectOrigen(String input) {
    final normalized = input.toLowerCase();
    if (normalized.contains('propio') ||
        normalized.contains('de la finca') ||
        normalized.contains('hecho en la finca')) {
      return 'propio';
    }
    return 'comprado';
  }

  String _extractFactura(String input) {
    final match = RegExp(
      r'(?:factura|ref|referencia|numero)\s*[:#-]?\s*([A-Za-z0-9-]+)',
      caseSensitive: false,
    ).firstMatch(input);
    return (match?.group(1) ?? '').trim();
  }

  bool _isValidDraft(Map<String, dynamic> draft, String originalCommand) {
    final insumo = (draft['insumo'] ?? '').toString().toLowerCase().trim();
    final fecha = (draft['fecha'] ?? '').toString().trim();

    if (fecha.isEmpty || insumo.isEmpty) {
      return false;
    }

    if (_invalidValues.contains(insumo) || insumo.length < 3) {
      return false;
    }

    if (!_looksLikeSupplyRecord(originalCommand) &&
        !_looksLikeSupplyRecord(insumo)) {
      return false;
    }

    return true;
  }

  String _normalizeTipo(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'organico' || normalized == 'orgÃ¡nico') {
      return 'organico';
    }
    return 'convencional';
  }

  String _normalizeOrigen(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'propio') {
      return 'propio';
    }
    return 'comprado';
  }

  String _capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text[0].toUpperCase() + text.substring(1);
  }
}
