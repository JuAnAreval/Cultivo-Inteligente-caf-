import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/fincas/device_location_service.dart';
import 'package:app_flutter_ai/core/services/fincas/finca_service.dart';
import 'package:app_flutter_ai/screens/cosechas/cosecha_list_screen.dart';
import 'package:app_flutter_ai/screens/lotes/lot_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FarmMapScreen extends StatefulWidget {
  const FarmMapScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen> {
  static const LatLng _defaultCenter = LatLng(4.5709, -74.2973);
  static const double _listSheetHeight = 320;

  final MapController _mapController = MapController();
  late Future<List<Map<String, dynamic>>> _farmsFuture;

  LatLng? _currentLocation;
  Map<String, dynamic>? _selectedFarm;
  bool _showFarmList = false;
  bool _isLocating = false;
  bool _didAutoFocus = false;

  @override
  void initState() {
    super.initState();
    _farmsFuture = _loadFarms();
  }

  Future<List<Map<String, dynamic>>> _loadFarms() async {
    final response = await FincaService.getAll(limit: 100);
    final rawList = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'];
    final currentUserId = SessionService.userId;

    if (rawList is! List) {
      return [];
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((farm) {
          if (currentUserId == null) {
            return true;
          }

          final createdBy = farm['createdBy'];
          if (createdBy is int) {
            return createdBy == currentUserId;
          }
          if (createdBy is String) {
            return int.tryParse(createdBy) == currentUserId;
          }
          return false;
        })
        .where((farm) => _parseCoordinate(farm['latitud']) != null)
        .where((farm) => _parseCoordinate(farm['longitud']) != null)
        .toList();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _didAutoFocus = false;
      _showFarmList = false;
      _selectedFarm = null;
      _farmsFuture = _loadFarms();
    });
    await _farmsFuture;
  }

  static double? _parseCoordinate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  void _focusAllFarms(List<Map<String, dynamic>> farms) {
    if (farms.isEmpty) {
      _mapController.move(_defaultCenter, 6.2);
      return;
    }

    if (farms.length == 1) {
      _focusFarm(farms.first, zoom: 14.4);
      return;
    }

    final points = farms
        .map((farm) {
          final lat = _parseCoordinate(farm['latitud']);
          final lng = _parseCoordinate(farm['longitud']);
          if (lat == null || lng == null) {
            return null;
          }
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();

    if (points.isEmpty) {
      _mapController.move(_defaultCenter, 6.2);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(52, 120, 52, 220),
      ),
    );
  }

  void _focusFarm(Map<String, dynamic> farm, {double zoom = 15.4}) {
    final lat = _parseCoordinate(farm['latitud']);
    final lng = _parseCoordinate(farm['longitud']);
    if (lat == null || lng == null) {
      return;
    }

    _mapController.move(LatLng(lat, lng), zoom);
    setState(() {
      _selectedFarm = farm;
      _showFarmList = false;
    });
  }

  Future<void> _focusCurrentLocation() async {
    if (_isLocating) {
      return;
    }

    setState(() => _isLocating = true);

    try {
      final point = await DeviceLocationService.getCurrentLatLng();
      if (!mounted) {
        return;
      }

      _mapController.move(point, 16);
      setState(() {
        _currentLocation = point;
      });
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

  void _openLots(Map<String, dynamic> farm) {
    final farmId = (farm['id'] ?? '').toString();
    final farmName = (farm['nombre'] ?? 'Finca').toString();
    if (farmId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LotListScreen(
          farmId: farmId,
          farmName: farmName,
        ),
      ),
    );
  }

  void _openCosechas(Map<String, dynamic> farm) {
    final farmId = (farm['id'] ?? '').toString();
    final farmName = (farm['nombre'] ?? 'Finca').toString();
    if (farmId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CosechaListScreen(
          farmId: farmId,
          farmName: farmName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = widget.embedded ? 116.0 : 24.0;

    final content = FutureBuilder<List<Map<String, dynamic>>>(
      future: _farmsFuture,
      builder: (context, snapshot) {
        final farms = snapshot.data ?? [];
        final markers = farms
            .map((farm) {
              final lat = _parseCoordinate(farm['latitud']);
              final lng = _parseCoordinate(farm['longitud']);
              if (lat == null || lng == null) {
                return null;
              }

              final isSelected =
                  (farm['id'] ?? '').toString() ==
                  (_selectedFarm?['id'] ?? '').toString();

              return Marker(
                point: LatLng(lat, lng),
                width: 54,
                height: 54,
                child: GestureDetector(
                  onTap: () => _focusFarm(farm),
                  child: _FarmPin(isSelected: isSelected),
                ),
              );
            })
            .whereType<Marker>()
            .toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              snapshot.connectionState == ConnectionState.done &&
              !_didAutoFocus &&
              !_showFarmList &&
              _selectedFarm == null) {
            _didAutoFocus = true;
            _focusAllFarms(farms);
          }
        });

        final floatingButtonBottom =
            bottomInset + (_showFarmList && farms.isNotEmpty ? _listSheetHeight + 14 : 0);

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 6.2,
                onTap: (_, __) {
                  if (_showFarmList) {
                    setState(() => _showFarmList = false);
                    return;
                  }
                  if (_selectedFarm != null) {
                    setState(() => _selectedFarm = null);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.appflutterai.app_flutter_ai',
                ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D8BFF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x223D8BFF),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TopOverlay(
                  farmCount: farms.length,
                  onBack: widget.embedded ? null : () => Navigator.pop(context),
                  onLocate: _focusCurrentLocation,
                  onRefresh: _refresh,
                  isLocating: _isLocating,
                  embedded: widget.embedded,
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset,
                child: const _StatusCard(
                  icon: Icons.public_rounded,
                  title: 'Cargando fincas',
                  subtitle: 'Estamos ubicando tus registros en el mapa.',
                  loading: true,
                ),
              )
            else if (snapshot.hasError)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset,
                child: _StatusCard(
                  icon: Icons.error_outline_rounded,
                  title: 'No se pudo cargar el mapa',
                  subtitle: snapshot.error.toString(),
                  actionLabel: 'Reintentar',
                  onAction: _refresh,
                ),
              )
            else if (farms.isEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset,
                child: const _StatusCard(
                  icon: Icons.home_work_outlined,
                  title: 'Aún no hay fincas para mostrar',
                  subtitle:
                      'Cuando registres fincas con coordenadas, aparecerán aquí sobre el mapa.',
                ),
              )
            else ...[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                right: 16,
                bottom: floatingButtonBottom,
                child: _MapFab(
                  icon: _showFarmList
                      ? Icons.close_rounded
                      : Icons.format_list_bulleted_rounded,
                  onTap: () {
                    setState(() {
                      _showFarmList = !_showFarmList;
                    });
                  },
                ),
              ),
              if (_selectedFarm != null && !_showFarmList)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: bottomInset,
                  child: _SelectedFarmCard(
                    farm: _selectedFarm!,
                    onOpenLots: () => _openLots(_selectedFarm!),
                    onOpenCosechas: () => _openCosechas(_selectedFarm!),
                    onClose: () {
                      setState(() => _selectedFarm = null);
                    },
                  ),
                ),
              if (_showFarmList)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: bottomInset,
                  child: _FarmListSheet(
                    farms: farms,
                    onSelectFarm: _focusFarm,
                  ),
                ),
            ],
          ],
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: content,
    );
  }
}

class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.farmCount,
    required this.onBack,
    required this.onLocate,
    required this.onRefresh,
    required this.isLocating,
    required this.embedded,
  });

  final int farmCount;
  final VoidCallback? onBack;
  final VoidCallback onLocate;
  final Future<void> Function() onRefresh;
  final bool isLocating;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!embedded) ...[
          _CircleMapButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.surfaceMuted),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.map_rounded,
                  color: AppColors.clayStrong,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Mapa de fincas',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$farmCount fincas ubicadas',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _CircleMapButton(
          icon: isLocating
              ? Icons.more_horiz_rounded
              : Icons.my_location_rounded,
          onTap: onLocate,
        ),
        const SizedBox(width: 12),
        _CircleMapButton(
          icon: Icons.refresh_rounded,
          onTap: () => onRefresh(),
        ),
      ],
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'map_list_fab',
      onPressed: onTap,
      backgroundColor: AppColors.moss,
      foregroundColor: AppColors.surface,
      elevation: 2,
      child: Icon(icon),
    );
  }
}

class _FarmListSheet extends StatelessWidget {
  const _FarmListSheet({
    required this.farms,
    required this.onSelectFarm,
  });

  final List<Map<String, dynamic>> farms;
  final void Function(Map<String, dynamic>) onSelectFarm;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: _FarmMapScreenState._listSheetHeight),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceMuted),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143E2F25),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Listado de fincas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Toca una finca para ubicarla',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: farms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final farm = farms[index];
                final area = (farm['area_hectareas'] ?? '').toString();
                return Material(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => onSelectFarm(farm),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.clayStrong,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (farm['nombre'] ?? 'Finca').toString(),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  (farm['ubicacion_texto'] ?? 'Sin ubicación')
                                      .toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (area.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$area hectareas',
                                style: const TextStyle(
                                  color: AppColors.soil,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedFarmCard extends StatelessWidget {
  const _SelectedFarmCard({
    required this.farm,
    required this.onOpenLots,
    required this.onOpenCosechas,
    required this.onClose,
  });

  final Map<String, dynamic> farm;
  final VoidCallback onOpenLots;
  final VoidCallback onOpenCosechas;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final nombre = (farm['nombre'] ?? 'Finca').toString();
    final ubicacion = (farm['ubicacion_texto'] ?? 'Sin ubicación').toString();
    final area = (farm['area_hectareas'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceMuted),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143E2F25),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalles de la finca',
                      style: TextStyle(
                        color: AppColors.clayStrong,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ubicacion,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CircleSoftButton(
                icon: Icons.close_rounded,
                onTap: onClose,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (area.isNotEmpty)
                _FarmInfoChip(
                  icon: Icons.crop_landscape_rounded,
                  text: '$area hectareas',
                ),
              if (area.isEmpty)
                const _FarmInfoChip(
                  icon: Icons.crop_landscape_rounded,
                  text: 'Area no definida',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenLots,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.moss,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Lotes'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenCosechas,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.clayStrong,
                    side: const BorderSide(color: AppColors.sand),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.agriculture_rounded),
                  label: const Text('Cosechas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CircularProgressIndicator(color: AppColors.moss)
          else
            Icon(icon, color: AppColors.clayStrong, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.moss,
                foregroundColor: AppColors.surface,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleMapButton extends StatelessWidget {
  const _CircleMapButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: AppColors.soil),
        ),
      ),
    );
  }
}

class _CircleSoftButton extends StatelessWidget {
  const _CircleSoftButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSoft,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 18, color: AppColors.soil),
        ),
      ),
    );
  }
}

class _FarmPin extends StatelessWidget {
  const _FarmPin({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSelected ? 18 : 14,
          height: isSelected ? 18 : 14,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.moss : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.surface : AppColors.clayStrong,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x143E2F25),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        Icon(
          Icons.location_on_rounded,
          color: isSelected ? AppColors.moss : AppColors.clayStrong,
          size: isSelected ? 30 : 28,
        ),
      ],
    );
  }
}

class _FarmInfoChip extends StatelessWidget {
  const _FarmInfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.moss),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
