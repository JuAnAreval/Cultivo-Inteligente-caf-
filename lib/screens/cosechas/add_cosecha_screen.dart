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
  final _anioController = TextEditingController();

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
    _anioController.text = (existing?['anio'] ?? DateTime.now().year).toString();
    _proceso = (existing?['proceso'] ?? '').toString();
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _kilosCerezaController.dispose();
    _kilosPergaminoController.dispose();
    _anioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = <String, dynamic>{
        'id_finca': widget.farmId,
        'fecha': _fechaController.text.trim(),
        'kilos_cereza': _kilosCerezaController.text.trim(),
        'kilos_pergamino': _kilosPergaminoController.text.trim(),
        'proceso': _proceso.trim(),
        'anio': _anioController.text.trim(),
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  String? _validatePeso(String? value) {
    final cereza = _kilosCerezaController.text.trim();
    final pergamino = _kilosPergaminoController.text.trim();
    if (cereza.isEmpty && pergamino.isEmpty) {
      return 'Ingresa kilos de cereza o pergamino';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCosecha != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar cosecha' : 'Registrar cosecha'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
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
                      hint: 'YYYY-MM-DD',
                      icon: Icons.event_rounded,
                      validator: _required,
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
                    Row(
                      children: [
                        Expanded(
                          child: _DropdownCard(
                            label: 'Proceso',
                            value: _proceso,
                            items: const [
                              DropdownMenuItem(value: '', child: Text('Sin definir')),
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _anioController,
                            label: 'Año',
                            hint: 'Ej: 2026',
                            icon: Icons.calendar_month_rounded,
                            keyboardType: TextInputType.number,
                            validator: _required,
                          ),
                        ),
                      ],
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
                    _PreviewRow(label: 'Año', value: _anioController.text),
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
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
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
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
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
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

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
