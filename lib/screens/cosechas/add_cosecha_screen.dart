import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/cosechas/cosecha_service.dart';
import 'package:flutter/material.dart';

class AddCosechaScreen extends StatefulWidget {
  const AddCosechaScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.existingCosecha,
  });

  final String farmId;
  final String farmName;
  final Map<String, dynamic>? existingCosecha;

  @override
  State<AddCosechaScreen> createState() => _AddCosechaScreenState();
}

class _AddCosechaScreenState extends State<AddCosechaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fechaController = TextEditingController();
  final _kilosCerezaController = TextEditingController();
  final _kilosPergaminoController = TextEditingController();

  late String _proceso;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCosecha;
    _fechaController.text = (existing?['fecha'] ?? '').toString();
    _kilosCerezaController.text = (existing?['kilos_cereza'] ?? '').toString();
    _kilosPergaminoController.text =
        (existing?['kilos_pergamino'] ?? '').toString();
    _proceso = (existing?['proceso'] ?? '').toString();

    _fechaController.addListener(_refresh);
    _kilosCerezaController.addListener(_refresh);
    _kilosPergaminoController.addListener(_refresh);
  }

  @override
  void dispose() {
    _fechaController.removeListener(_refresh);
    _kilosCerezaController.removeListener(_refresh);
    _kilosPergaminoController.removeListener(_refresh);
    _fechaController.dispose();
    _kilosCerezaController.dispose();
    _kilosPergaminoController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final currentYear = now.year;
    final initialDate = _parseCurrentYearDate(_fechaController.text) ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(currentYear, 1, 1),
      lastDate: DateTime(currentYear, 12, 31),
      helpText: 'Selecciona la fecha de la cosecha',
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
      final fecha = _parseCurrentYearDate(_fechaController.text.trim())!;
      final payload = <String, dynamic>{
        'id_finca': widget.farmId,
        'fecha': _formatDate(fecha),
        'kilos_cereza': _parseNumber(_kilosCerezaController.text.trim()),
        'kilos_pergamino': _parseNumber(_kilosPergaminoController.text.trim()),
        'proceso': _proceso.trim(),
        'anio': fecha.year,
      };

      final existingId = (widget.existingCosecha?['id'] ?? '').toString();
      if (existingId.isEmpty) {
        await CosechaService.create(payload);
      } else {
        await CosechaService.update(existingId, payload);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingId.isEmpty
                ? 'Cosecha registrada correctamente.'
                : 'Cosecha actualizada correctamente.',
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
          content: Text('No se pudo guardar la cosecha: $error'),
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

  String? _validateFecha(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Selecciona una fecha';
    }

    if (_parseCurrentYearDate(value.trim()) == null) {
      return 'Usa una fecha válida del año actual';
    }

    return null;
  }

  String? _validatePeso(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }

    final parsed = _parseNumber(value.trim());
    if (parsed == null) {
      return 'Ingresa un número válido';
    }

    if (parsed < 0) {
      return 'El valor no puede ser negativo';
    }

    return null;
  }

  String? _validateProceso(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Selecciona un proceso';
    }
    return null;
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

  double? _parseNumber(String value) {
    return double.tryParse(value.replaceAll(',', '.'));
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCosecha != null;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final parsedDate = _parseCurrentYearDate(_fechaController.text.trim());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar cosecha' : 'Registrar cosecha'),
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
                      isEditing ? 'Editar cosecha' : 'Nueva cosecha',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este registro quedará asociado a la finca ${widget.farmName}.',
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
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _kilosCerezaController,
                            label: 'Kilos cereza',
                            hint: 'Ej: 320',
                            icon: Icons.agriculture_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _validatePeso,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _kilosPergaminoController,
                            label: 'Kilos pergamino',
                            hint: 'Ej: 72',
                            icon: Icons.grain_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _validatePeso,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DropdownCard(
                      label: 'Proceso',
                      value: _proceso,
                      validator: _validateProceso,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Selecciona')),
                        DropdownMenuItem(value: 'MIEL', child: Text('MIEL')),
                        DropdownMenuItem(
                          value: 'NATURAL',
                          child: Text('NATURAL'),
                        ),
                        DropdownMenuItem(
                          value: 'LAVADO',
                          child: Text('LAVADO'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _proceso = value ?? '');
                      },
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
                    _PreviewRow(label: 'Finca', value: widget.farmName),
                    _PreviewRow(label: 'Fecha', value: _fechaController.text),
                    _PreviewRow(
                      label: 'Kilos cereza',
                      value: _kilosCerezaController.text,
                    ),
                    _PreviewRow(
                      label: 'Kilos pergamino',
                      value: _kilosPergaminoController.text,
                    ),
                    _PreviewRow(label: 'Proceso', value: _proceso),
                    _PreviewRow(
                      label: 'Año',
                      value: parsedDate == null ? '' : parsedDate.year.toString(),
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
                        : (isEditing ? 'Actualizar cosecha' : 'Guardar cosecha'),
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
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
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
          keyboardType: keyboardType,
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

class _DropdownCard extends StatelessWidget {
  const _DropdownCard({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

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
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
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
