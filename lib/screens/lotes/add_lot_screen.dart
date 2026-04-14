import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/lotes/lote_service.dart';
import 'package:flutter/material.dart';

class AddLotScreen extends StatefulWidget {
  const AddLotScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.existingLot,
  });

  final String farmId;
  final String farmName;
  final Map<String, dynamic>? existingLot;

  @override
  State<AddLotScreen> createState() => _AddLotScreenState();
}

class _AddLotScreenState extends State<AddLotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _tipoCafeController = TextEditingController();
  final _edadCultivoController = TextEditingController();
  final _hectareasController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existingLot = widget.existingLot;
    if (existingLot != null) {
      _nombreController.text = (existingLot['nombre_lote'] ?? '').toString();
      _tipoCafeController.text = (existingLot['tipo_cafe'] ?? '').toString();
      _edadCultivoController.text =
          (existingLot['edad_cultivo'] ?? '').toString();
      _hectareasController.text =
          (existingLot['hectareas_lote'] ?? '').toString();
    }
    _nombreController.addListener(_refresh);
    _tipoCafeController.addListener(_refresh);
    _edadCultivoController.addListener(_refresh);
    _hectareasController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nombreController.removeListener(_refresh);
    _tipoCafeController.removeListener(_refresh);
    _edadCultivoController.removeListener(_refresh);
    _hectareasController.removeListener(_refresh);
    _nombreController.dispose();
    _tipoCafeController.dispose();
    _edadCultivoController.dispose();
    _hectareasController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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
        'nombre_lote': _nombreController.text.trim(),
        'tipo_cafe': _tipoCafeController.text.trim(),
        'edad_cultivo': double.parse(
          _edadCultivoController.text.trim().replaceAll(',', '.'),
        ),
        'hectareas_lote': double.parse(
          _hectareasController.text.trim().replaceAll(',', '.'),
        ),
      };

      final existingId = (widget.existingLot?['id'] ?? '').toString();
      if (existingId.isEmpty) {
        await LoteService.create(payload);
      } else {
        await LoteService.update(existingId, payload);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingId.isEmpty
                ? 'Lote creado correctamente.'
                : 'Lote actualizado correctamente.',
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
          content: Text('No se pudo crear el lote: $error'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingLot == null ? 'Registrar lote' : 'Editar lote',
        ),
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
                      widget.existingLot == null ? 'Nuevo lote' : 'Editar lote',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este lote quedara asociado a la finca ${widget.farmName}.',
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
                    _LotTextField(
                      controller: _nombreController,
                      label: 'Nombre del lote',
                      hint: 'Ej: Lote Norte',
                      icon: Icons.grid_view_rounded,
                      validator: _validateRequired,
                    ),
                    const SizedBox(height: 16),
                    _LotTextField(
                      controller: _tipoCafeController,
                      label: 'Tipo de cafe',
                      hint: 'Ej: Castillo',
                      icon: Icons.local_florist_rounded,
                      validator: _validateRequired,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _LotTextField(
                            controller: _edadCultivoController,
                            label: 'Edad cultivo',
                            hint: 'Ej: 2',
                            icon: Icons.timelapse_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _validateNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LotTextField(
                            controller: _hectareasController,
                            label: 'Hectareas',
                            hint: 'Ej: 1.5',
                            icon: Icons.crop_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _validateNumber,
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
                    _PreviewRow(label: 'Nombre lote', value: _nombreController.text),
                    _PreviewRow(label: 'Tipo cafe', value: _tipoCafeController.text),
                    _PreviewRow(
                      label: 'Edad cultivo',
                      value: _edadCultivoController.text,
                    ),
                    _PreviewRow(
                      label: 'Hectareas lote',
                      value: _hectareasController.text,
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
                        : (widget.existingLot == null
                            ? 'Guardar lote'
                            : 'Actualizar lote'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }

    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Ingresa un numero valido';
    }

    return null;
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

class _LotTextField extends StatelessWidget {
  const _LotTextField({
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
