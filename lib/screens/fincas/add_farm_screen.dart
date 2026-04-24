import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/fincas/device_location_service.dart';
import 'package:app_flutter_ai/core/services/fincas/finca_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AddFarmScreen extends StatefulWidget {
  const AddFarmScreen({
    super.key,
    this.existingFarm,
  });

  final Map<String, dynamic>? existingFarm;

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  static const LatLng _defaultCenter = LatLng(4.5709, -74.2973);

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _latitudController = TextEditingController();
  final _longitudController = TextEditingController();
  final _areaController = TextEditingController();
  final MapController _mapController = MapController();

  bool _isSaving = false;
  bool _isLocating = false;
  LatLng? _selectedPoint = _defaultCenter;
  double _currentZoom = 6.5;

  @override
  void initState() {
    super.initState();
    final existingFarm = widget.existingFarm;
    if (existingFarm != null) {
      _nombreController.text = (existingFarm['nombre'] ?? '').toString();
      _ubicacionController.text =
          (existingFarm['ubicacion_texto'] ?? '').toString();
      _areaController.text = (existingFarm['area_hectareas'] ?? '').toString();

      final initialLat = double.tryParse(
        (existingFarm['latitud'] ?? '').toString().replaceAll(',', '.'),
      );
      final initialLng = double.tryParse(
        (existingFarm['longitud'] ?? '').toString().replaceAll(',', '.'),
      );
      final initialPoint = initialLat != null && initialLng != null
          ? LatLng(initialLat, initialLng)
          : _defaultCenter;
      _syncCoordinates(initialPoint);
      _selectedPoint = initialPoint;
      _currentZoom = 14;
    } else {
      _syncCoordinates(_defaultCenter);
    }

    _nombreController.addListener(_refresh);
    _ubicacionController.addListener(_refresh);
    _areaController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nombreController.removeListener(_refresh);
    _ubicacionController.removeListener(_refresh);
    _areaController.removeListener(_refresh);
    _nombreController.dispose();
    _ubicacionController.dispose();
    _latitudController.dispose();
    _longitudController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _syncCoordinates(LatLng point) {
    _selectedPoint = point;
    _latitudController.text = point.latitude.toStringAsFixed(6);
    _longitudController.text = point.longitude.toStringAsFixed(6);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _syncCoordinates(point);
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLocating = true);

    try {
      final point = await DeviceLocationService.getCurrentLatLng();
      if (!mounted) {
        return;
      }

      setState(() {
        _syncCoordinates(point);
        _currentZoom = 16;
      });
      _mapController.move(point, _currentZoom);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
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
        'nombre': _nombreController.text.trim(),
        'ubicacion_texto': _ubicacionController.text.trim(),
        'latitud': double.parse(
          _latitudController.text.trim().replaceAll(',', '.'),
        ),
        'longitud': double.parse(
          _longitudController.text.trim().replaceAll(',', '.'),
        ),
        'area_hectareas': double.parse(
          _areaController.text.trim().replaceAll(',', '.'),
        ),
      };

      final existingId = (widget.existingFarm?['id'] ?? '').toString();
      if (existingId.isEmpty) {
        await FincaService.create(payload);
      } else {
        await FincaService.update(existingId, payload);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingId.isEmpty
                ? 'Finca creada correctamente.'
                : 'Finca actualizada correctamente.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _formKey.currentState?.reset();
      _nombreController.clear();
      _ubicacionController.clear();
      _areaController.clear();
      _syncCoordinates(_defaultCenter);
      setState(() {});
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear la finca: $error'),
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
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingFarm == null ? 'Registrar finca' : 'Editar finca',
        ),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.sand),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.existingFarm == null ? 'Nueva finca' : 'Editar finca',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona la ubicación directamente en el mapa. La latitud y la longitud se llenan automáticamente al tocar el punto.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FieldCard(
                child: Column(
                  children: [
                    _FarmTextField(
                      controller: _nombreController,
                      label: 'Nombre',
                      hint: 'Ej: Finca El Recuerdo',
                      icon: Icons.home_work_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el nombre de la finca';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _FarmTextField(
                      controller: _ubicacionController,
                      label: 'Ubicación',
                      hint: 'Ej: Vereda La Esperanza, Neiva',
                      icon: Icons.place_rounded,
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa una ubicación';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.moss,
                          side: const BorderSide(color: AppColors.sand),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.moss,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: Text(
                          _isLocating
                              ? 'Buscando ubicación...'
                              : 'Usar ubicación actual',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MapPickerCard(
                      selectedPoint: _selectedPoint,
                      currentZoom: _currentZoom,
                      mapController: _mapController,
                      onMapTap: _onMapTap,
                      onUseCurrentLocation: _useCurrentLocation,
                      isLocating: _isLocating,
                      onZoomIn: () {
                        setState(() {
                          _currentZoom = (_currentZoom + 1).clamp(3, 18);
                          _mapController.move(
                            _selectedPoint ?? _defaultCenter,
                            _currentZoom,
                          );
                        });
                      },
                      onZoomOut: () {
                        setState(() {
                          _currentZoom = (_currentZoom - 1).clamp(3, 18);
                          _mapController.move(
                            _selectedPoint ?? _defaultCenter,
                            _currentZoom,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _LocationStatusCard(
                      hasSelectedPoint:
                          _latitudController.text.trim().isNotEmpty &&
                          _longitudController.text.trim().isNotEmpty,
                    ),
                    const SizedBox(height: 16),
                    _FarmTextField(
                      controller: _areaController,
                      label: 'Área en hectáreas',
                      hint: 'Ej: 12.5',
                      icon: Icons.crop_landscape_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateDecimal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _PreviewCard(
                nombre: _nombreController.text,
                ubicacion: _ubicacionController.text,
                area: _areaController.text,
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
                        : (widget.existingFarm == null
                            ? 'Guardar finca'
                            : 'Actualizar finca'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateDecimal(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }

    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Ingresa un número válido';
    }

    if (parsed < 0) {
      return 'El valor no puede ser negativo';
    }

    return null;
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});

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

class _MapPickerCard extends StatelessWidget {
  const _MapPickerCard({
    required this.selectedPoint,
    required this.currentZoom,
    required this.mapController,
    required this.onMapTap,
    required this.onUseCurrentLocation,
    required this.isLocating,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final LatLng? selectedPoint;
  final double currentZoom;
  final MapController mapController;
  final void Function(TapPosition, LatLng) onMapTap;
  final VoidCallback onUseCurrentLocation;
  final bool isLocating;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final center = selectedPoint ?? _AddFarmScreenState._defaultCenter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selección en mapa',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: currentZoom,
                    onTap: onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.appflutterai.app_flutter_ai',
                    ),
                    if (selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedPoint!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.clayStrong,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _MapButton(
                        icon: isLocating
                            ? Icons.more_horiz_rounded
                            : Icons.my_location_rounded,
                        onTap: onUseCurrentLocation,
                      ),
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: Icons.add_rounded,
                        onTap: onZoomIn,
                      ),
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: Icons.remove_rounded,
                        onTap: onZoomOut,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Toca el mapa o usa tu ubicación actual para seleccionar el punto.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.soil),
        ),
      ),
    );
  }
}

class _FarmTextField extends StatelessWidget {
  const _FarmTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
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
          keyboardType: keyboardType,
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.nombre,
    required this.ubicacion,
    required this.area,
  });

  final String nombre;
  final String ubicacion;
  final String area;

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
          _PreviewRow(label: 'Nombre', value: nombre),
          _PreviewRow(label: 'Ubicación', value: ubicacion),
          _PreviewRow(label: 'Área en hectáreas', value: area),
        ],
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.hasSelectedPoint,
  });

  final bool hasSelectedPoint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            hasSelectedPoint ? AppColors.backgroundSoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSelectedPoint ? AppColors.sand : AppColors.surfaceMuted,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasSelectedPoint
                ? Icons.check_circle_rounded
                : Icons.location_searching_rounded,
            color: hasSelectedPoint ? AppColors.moss : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasSelectedPoint
                  ? 'Ubicación seleccionada en el mapa'
                  : 'Selecciona un punto en el mapa para guardar la finca',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
