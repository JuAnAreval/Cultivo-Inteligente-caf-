import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/insumos/insumo_servies.dart';
import 'package:flutter/material.dart';

class AddInsumoScreen extends StatefulWidget {
  const AddInsumoScreen({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.farmName,
    this.existingInsumo,
  });

  final String lotId;
  final String lotName;
  final String farmName;
  final Map<String, dynamic>? existingInsumo;

  @override
  State<AddInsumoScreen> createState() => _AddInsumoScreenState();
}

class _AddInsumoScreenState extends State<AddInsumoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _insumoController = TextEditingController();
  final _ingredientesController = TextEditingController();
  final _fechaController = TextEditingController();
  final _facturaController = TextEditingController();

  late String _tipo;
  late String _origen;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingInsumo;
    _insumoController.text = (existing?['insumo'] ?? '').toString();
    _ingredientesController.text =
        (existing?['ingredientes_activos'] ?? '').toString();
    _fechaController.text = (existing?['fecha'] ?? '').toString();
    _facturaController.text = (existing?['factura'] ?? '').toString();
    _tipo = ((existing?['tipo'] ?? 'organico').toString()).toLowerCase();
    _origen = ((existing?['origen'] ?? 'propio').toString()).toLowerCase();
  }

  @override
  void dispose() {
    _insumoController.dispose();
    _ingredientesController.dispose();
    _fechaController.dispose();
    _facturaController.dispose();
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
        'id_lote': widget.lotId,
        'insumo': _insumoController.text.trim(),
        'ingredientes_activos': _ingredientesController.text.trim(),
        'fecha': _fechaController.text.trim(),
        'tipo': _tipo,
        'origen': _origen,
        'factura': _facturaController.text.trim(),
      };

      final existingId = (widget.existingInsumo?['id'] ?? '').toString();
      if (existingId.isEmpty) {
        await InsumoService.create(payload);
      } else {
        await InsumoService.update(existingId, payload);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingId.isEmpty
                ? 'Insumo registrado correctamente.'
                : 'Insumo actualizado correctamente.',
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
          content: Text('No se pudo guardar el insumo: $error'),
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
    final isEditing = widget.existingInsumo != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar insumo' : 'Registrar insumo'),
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
                      isEditing ? 'Editar insumo' : 'Nuevo insumo',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este registro quedara asociado al lote ${widget.lotName} de la finca ${widget.farmName}.',
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
                      controller: _insumoController,
                      label: 'Insumo',
                      hint: 'Ej: Fertilizante cafetero',
                      icon: Icons.inventory_2_rounded,
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _ingredientesController,
                      label: 'Ingredientes activos',
                      hint: 'Ej: NPK 17-6-18',
                      icon: Icons.science_rounded,
                      maxLines: 2,
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
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
                          child: _DropdownCard(
                            label: 'Tipo',
                            value: _tipo,
                            items: const [
                              DropdownMenuItem(
                                value: 'organico',
                                child: Text('Organico'),
                              ),
                              DropdownMenuItem(
                                value: 'convencional',
                                child: Text('Convencional'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _tipo = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DropdownCard(
                            label: 'Origen',
                            value: _origen,
                            items: const [
                              DropdownMenuItem(
                                value: 'propio',
                                child: Text('Propio'),
                              ),
                              DropdownMenuItem(
                                value: 'comprado',
                                child: Text('Comprado'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _origen = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _facturaController,
                      label: 'Factura',
                      hint: 'Ej: FAC-001 o nota interna',
                      icon: Icons.receipt_long_rounded,
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
                    _PreviewRow(label: 'Insumo', value: _insumoController.text),
                    _PreviewRow(
                      label: 'Ingredientes',
                      value: _ingredientesController.text,
                    ),
                    _PreviewRow(label: 'Fecha', value: _fechaController.text),
                    _PreviewRow(label: 'Tipo', value: _tipo),
                    _PreviewRow(label: 'Origen', value: _origen),
                    _PreviewRow(label: 'Factura', value: _facturaController.text),
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
                        : (isEditing ? 'Actualizar insumo' : 'Guardar insumo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
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
          maxLines: maxLines,
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
