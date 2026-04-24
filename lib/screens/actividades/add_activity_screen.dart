import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/actividades/actividad_campo_service.dart';
import 'package:flutter/material.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.farmName,
    this.existingActivity,
  });

  final String lotId;
  final String lotName;
  final String farmName;
  final Map<String, dynamic>? existingActivity;

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  static const List<String> _doseRequiredKeywords = [
    'fertiliz',
    'plaga',
    'insect',
    'fungic',
    'encal',
    'cal',
    'rieg',
    'nutric',
  ];

  final _formKey = GlobalKey<FormState>();
  final _fechaController = TextEditingController();
  final _actividadController = TextEditingController();
  final _aplicacionesController = TextEditingController();
  final _dosisController = TextEditingController();
  final _observacionesController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingActivity;
    _fechaController.text = (existing?['fecha'] ?? '').toString();
    _actividadController.text = (existing?['actividad'] ?? '').toString();
    _aplicacionesController.text = (existing?['aplicaciones'] ?? '').toString();
    _dosisController.text = (existing?['dosis'] ?? '').toString();
    _observacionesController.text =
        (existing?['observaciones_responsable'] ?? '').toString();

    _fechaController.addListener(_refresh);
    _actividadController.addListener(_refresh);
    _aplicacionesController.addListener(_refresh);
    _dosisController.addListener(_refresh);
    _observacionesController.addListener(_refresh);
  }

  @override
  void dispose() {
    _fechaController.removeListener(_refresh);
    _actividadController.removeListener(_refresh);
    _aplicacionesController.removeListener(_refresh);
    _dosisController.removeListener(_refresh);
    _observacionesController.removeListener(_refresh);
    _fechaController.dispose();
    _actividadController.dispose();
    _aplicacionesController.dispose();
    _dosisController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final initialDate = _parseCurrentYearDate(_fechaController.text) ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, 1, 1),
      lastDate: DateTime(now.year, 12, 31),
      helpText: 'Selecciona la fecha de la actividad',
    );

    if (selectedDate == null) {
      return;
    }

    _fechaController.text = _formatDate(selectedDate);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = <String, dynamic>{
        'id_lote': widget.lotId,
        'fecha': _formatDate(_parseCurrentYearDate(_fechaController.text.trim())!),
        'actividad': _actividadController.text.trim(),
        'aplicaciones': _aplicacionesController.text.trim(),
        'dosis': _dosisController.text.trim(),
        'observaciones_responsable': _observacionesController.text.trim(),
      };

      final existingId = (widget.existingActivity?['id'] ?? '').toString();
      if (existingId.isEmpty) {
        await ActividadCampoService.create(payload);
      } else {
        await ActividadCampoService.update(existingId, payload);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingId.isEmpty
                ? 'Actividad registrada correctamente.'
                : 'Actividad actualizada correctamente.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la actividad: $error'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  String? _validateFecha(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Selecciona una fecha';
    }

    if (_parseCurrentYearDate(value.trim()) == null) {
      return 'Usa una fecha válida del año actual';
    }

    return null;
  }

  String? _validateDosis(String? value) {
    if (_doseIsRequiredForActivity(_actividadController.text.trim()) &&
        (value == null || value.trim().isEmpty)) {
      return 'Esta actividad requiere dosis';
    }
    return null;
  }

  bool _doseIsRequiredForActivity(String activity) {
    final normalized = activity.toLowerCase();
    return _doseRequiredKeywords.any(normalized.contains);
  }

  DateTime? _parseCurrentYearDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      return null;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    if (year != DateTime.now().year) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }

    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }

    return parsed;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingActivity != null;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar actividad' : 'Registrar actividad'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 18, 18, bottomSafeArea + 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Editar actividad' : 'Nueva actividad',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este registro quedará asociado al lote ${widget.lotName} de la finca ${widget.farmName}.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionCard(
                child: Column(
                  children: [
                    _Field(
                      controller: _fechaController,
                      label: 'Fecha',
                      hint: 'Selecciona una fecha',
                      icon: Icons.event_rounded,
                      readOnly: true,
                      onTap: _pickFecha,
                      validator: _validateFecha,
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _actividadController,
                      label: 'Actividad',
                      hint: 'Ej: Plateo manual',
                      icon: Icons.agriculture_rounded,
                      maxLines: 2,
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _aplicacionesController,
                      label: 'Aplicaciones',
                      hint: 'Productos o aplicaciones realizadas',
                      icon: Icons.science_rounded,
                      maxLines: 2,
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _dosisController,
                      label: 'Dosis',
                      hint: 'Cantidades o dosis aplicadas, si corresponde',
                      icon: Icons.straighten_rounded,
                      validator: _validateDosis,
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _observacionesController,
                      label: 'Observaciones y responsable',
                      hint: 'Notas adicionales o responsable',
                      icon: Icons.note_alt_rounded,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vista previa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PreviewRow(label: 'Lote', value: widget.lotName),
                    _PreviewRow(label: 'Fecha', value: _fechaController.text),
                    _PreviewRow(
                      label: 'Actividad',
                      value: _actividadController.text,
                    ),
                    _PreviewRow(
                      label: 'Aplicaciones',
                      value: _aplicacionesController.text,
                    ),
                    _PreviewRow(label: 'Dosis', value: _dosisController.text),
                    _PreviewRow(
                      label: 'Observaciones',
                      value: _observacionesController.text,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.moss,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving
                        ? 'Guardando...'
                        : (isEditing
                            ? 'Actualizar actividad'
                            : 'Guardar actividad'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: Icon(icon, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
