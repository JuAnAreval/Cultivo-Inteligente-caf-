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

    final safeCommand = normalizedCommand.length > 280
        ? normalizedCommand.substring(0, 280)
        : normalizedCommand;

    final rules = '''
Extrae un registro de insumo agricola del lote "$lotName" de la finca "$farmName".

Responde solo JSON puro.
Si el texto no describe un insumo agricola valido, responde:
{"error":"No se detecto un registro de insumo valido."}

Usa este formato exacto:
{
  "insumo": "",
  "ingredientes_activos": "",
  "fecha": "$today",
  "tipo": "organico",
  "origen": "propio",
  "factura": ""
}

Reglas:
- insumo: nombre corto del insumo.
- ingredientes_activos: composicion, referencia o ingrediente activo. Si no hay, "".
- fecha: YYYY-MM-DD. Si falta, usa $today.
- tipo: solo "organico" o "convencional". Si no es claro, usa "convencional".
- origen: solo "propio" o "comprado". Si no es claro, usa "comprado".
- factura: numero, referencia o nota. Si no hay, "".
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
        'error': (result['error'] ?? 'No se detecto un insumo valido.')
            .toString(),
      };
    }

    if (!_isValidDraft(result, normalizedCommand)) {
      return {
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
    if (normalized == 'organico' || normalized == 'orgánico') {
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
