import 'dart:ui' as ui;

import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/fincas/device_location_service.dart';
import 'package:app_flutter_ai/core/services/fincas/finca_service.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:app_flutter_ai/screens/cosechas/cosecha_list_screen.dart';
import 'package:app_flutter_ai/screens/fincas/add_farm_screen.dart';
import 'package:app_flutter_ai/screens/lotes/lot_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FarmMapScreen extends StatefulWidget {
  const FarmMapScreen({
    super.key,
    this.embedded = false,
    this.onGoToFincas,
  });

  final bool embedded;
  final VoidCallback? onGoToFincas;

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen>
    with SingleTickerProviderStateMixin {
  static const LatLng _defaultCenter = LatLng(4.5709, -74.2973);
  static const double _embeddedBottomInset = 154;
  static const double _sheetTopInset = 110;

  final MapController _mapController = MapController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _farmsFuture;

  late final AnimationController _mapAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _zoomAnimation;

  LatLng? _currentLocation;
  Map<String, dynamic>? _selectedFarm;
  bool _showFarmList = false;
  bool _isLocating = false;
  bool _didAutoFocus = false;
  double _currentZoom = 6.2;
  LatLng _currentCenter = _defaultCenter;

  @override
  void initState() {
    super.initState();
    _farmsFuture = _loadFarms();

    _mapAnimationController.addListener(() {
      if (_latAnimation == null || _lngAnimation == null || _zoomAnimation == null) {
        return;
      }

      final target = LatLng(_latAnimation!.value, _lngAnimation!.value);
      _currentCenter = target;
      _currentZoom = _zoomAnimation!.value;
      _mapController.move(target, _currentZoom);
    });
  }

  @override
  void dispose() {
    _mapAnimationController.dispose();
    super.dispose();
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

    final farms = rawList
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
        .toList();

    final enrichedFarms = <Map<String, dynamic>>[];
    for (final farm in farms) {
      final localId = _farmLocalId(farm);
      int lotesCount = 0;
      int cosechasCount = 0;

      if (localId != null) {
        final lotes = await _databaseHelper.getVisibleLotesByFinca(localId);
        final cosechas =
            await _databaseHelper.getVisibleCosechasByFinca(localId);
        lotesCount = lotes.length;
        cosechasCount = cosechas
            .where((row) => (_extractYear(row) ?? DateTime.now().year) == DateTime.now().year)
            .length;
      }

      enrichedFarms.add({
        ...farm,
        'lotes_count': lotesCount,
        'cosechas_current_year': cosechasCount,
        'has_coordinates':
            _parseCoordinate(farm['latitud']) != null &&
            _parseCoordinate(farm['longitud']) != null,
      });
    }

    return enrichedFarms;
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

  static int? _extractYear(Map<String, dynamic> row) {
    final explicitYear = DatabaseHelper.toInt(row['anio'] ?? row['año']);
    if (explicitYear != null) {
      return explicitYear;
    }

    final rawDate = row['fecha']?.toString();
    if (rawDate == null || rawDate.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawDate)?.year;
  }

  int? _farmLocalId(Map<String, dynamic> farm) {
    final rawId = farm['id'] ?? farm['local_id'];
    if (rawId is int) {
      return rawId;
    }
    if (rawId is num) {
      return rawId.toInt();
    }
    if (rawId is String) {
      return int.tryParse(rawId);
    }
    return null;
  }

  List<Map<String, dynamic>> _farmsWithCoordinates(List<Map<String, dynamic>> farms) {
    return farms.where((farm) => farm['has_coordinates'] == true).toList();
  }

  void _fitAllFarms(List<Map<String, dynamic>> farms) {
    final locatedFarms = _farmsWithCoordinates(farms);
    if (locatedFarms.isEmpty) {
      _animateMapMove(_defaultCenter, 6.2);
      return;
    }

    if (locatedFarms.length == 1) {
      final point = _farmPoint(locatedFarms.first);
      if (point != null) {
        _animateMapMove(point, 14.1);
      }
      return;
    }

    final points = locatedFarms.map(_farmPoint).whereType<LatLng>().toList();
    if (points.isEmpty) {
      _animateMapMove(_defaultCenter, 6.2);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(52, 120, 52, 250),
      ),
    );
    _currentCenter = bounds.center;
    _currentZoom = _mapController.camera.zoom;
    setState(() => _selectedFarm = null);
  }

  LatLng? _farmPoint(Map<String, dynamic> farm) {
    final lat = _parseCoordinate(farm['latitud']);
    final lng = _parseCoordinate(farm['longitud']);
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
  }

  void _animateMapMove(LatLng target, double targetZoom) {
    _mapAnimationController.stop();
    _latAnimation = Tween<double>(
      begin: _currentCenter.latitude,
      end: target.latitude,
    ).animate(CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    _lngAnimation = Tween<double>(
      begin: _currentCenter.longitude,
      end: target.longitude,
    ).animate(CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    _zoomAnimation = Tween<double>(
      begin: _currentZoom,
      end: targetZoom,
    ).animate(CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    _mapAnimationController
      ..reset()
      ..forward();
  }

  void _focusFarm(
    Map<String, dynamic> farm, {
    bool openDetail = true,
  }) {
    final point = _farmPoint(farm);
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta finca no tiene ubicación registrada.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isAlreadySelected =
        (farm['id'] ?? '').toString() == (_selectedFarm?['id'] ?? '').toString();

    if (!isAlreadySelected) {
      _animateMapMove(point, 15.4);
    }

    setState(() {
      _selectedFarm = openDetail ? farm : _selectedFarm;
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

      _animateMapMove(point, 16);
      setState(() => _currentLocation = point);
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

  Future<void> _editFarmLocation(Map<String, dynamic> farm) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFarmScreen(existingFarm: farm),
      ),
    );

    if (updated == true) {
      await _refresh();
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
    final bottomInset = widget.embedded ? _embeddedBottomInset : 26.0;

    final content = FutureBuilder<List<Map<String, dynamic>>>(
      future: _farmsFuture,
      builder: (context, snapshot) {
        final farms = snapshot.data ?? const <Map<String, dynamic>>[];
        final mappedFarms = _farmsWithCoordinates(farms);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              snapshot.connectionState == ConnectionState.done &&
              !_didAutoFocus) {
            _didAutoFocus = true;
            _fitAllFarms(farms);
          }
        });

        final markers = mappedFarms
            .map(
              (farm) => Marker(
                point: _farmPoint(farm)!,
                width: 120,
                height: 86,
                child: GestureDetector(
                  onTap: () => _focusFarm(farm),
                  child: _FarmMarker(
                    label: (farm['nombre'] ?? 'Finca').toString(),
                    isSelected: (farm['id'] ?? '').toString() ==
                        (_selectedFarm?['id'] ?? '').toString(),
                  ),
                ),
              ),
            )
            .toList();

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 6.2,
                onMapReady: () {
                  _currentCenter = _mapController.camera.center;
                  _currentZoom = _mapController.camera.zoom;
                },
                onPositionChanged: (camera, hasGesture) {
                  _currentCenter = camera.center;
                  _currentZoom = camera.zoom;
                },
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
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D8BFF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 3,
                            ),
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
                child: _MapHeader(
                  farmCount: mappedFarms.length,
                  onBack: widget.embedded ? null : () => Navigator.pop(context),
                  onLocate: _focusCurrentLocation,
                  onRefresh: _refresh,
                  isLocating: _isLocating,
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset + 132,
                child: const _MapStateCard(
                  icon: Icons.public_rounded,
                  title: 'Cargando mapa',
                  subtitle: 'Estamos preparando tus fincas ubicadas.',
                  loading: true,
                ),
              )
            else if (snapshot.hasError)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset + 132,
                child: _MapStateCard(
                  icon: Icons.error_outline_rounded,
                  title: 'No se pudo cargar el mapa',
                  subtitle: snapshot.error.toString(),
                  actionLabel: 'Reintentar',
                  onAction: _refresh,
                ),
              )
            else if (mappedFarms.isEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset + 132,
                child: _MapStateCard(
                  icon: Icons.map_outlined,
                  title: 'Ninguna finca tiene ubicación registrada',
                  subtitle:
                      'Asigna coordenadas a tus fincas para verlas sobre el mapa.',
                  actionLabel: 'Ir a mis fincas',
                  onAction: widget.onGoToFincas,
                ),
              ),
            if (_selectedFarm != null && mappedFarms.isNotEmpty && !_showFarmList)
              Positioned(
                top: 92,
                right: 16,
                child: _MiniMapAction(
                  icon: Icons.filter_center_focus_rounded,
                  label: 'Ver todas',
                  onTap: () {
                    _fitAllFarms(farms);
                  },
                ),
              ),
            if (mappedFarms.isNotEmpty && !_selectedFarmIsShowingListHidden())
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset,
                child: Center(
                  child: _ListFarmButton(
                    isOpen: _showFarmList,
                    onTap: () {
                      setState(() => _showFarmList = !_showFarmList);
                    },
                  ),
                ),
              ),
            if (_showFarmList && farms.isNotEmpty)
              Positioned.fill(
                top: _sheetTopInset,
                left: 16,
                right: 16,
                bottom: bottomInset - 6,
                child: _FarmListSheet(
                  farms: farms,
                  onSelectFarm: _focusFarm,
                  onClose: () => setState(() => _showFarmList = false),
                ),
              ),
            if (_selectedFarm != null && !_showFarmList)
              Positioned.fill(
                top: _sheetTopInset,
                left: 16,
                right: 16,
                bottom: bottomInset - 6,
                child: _FarmDetailSheet(
                  farm: _selectedFarm!,
                  onOpenLots: () => _openLots(_selectedFarm!),
                  onOpenCosechas: () => _openCosechas(_selectedFarm!),
                  onEditLocation: () => _editFarmLocation(_selectedFarm!),
                  onClose: () => setState(() => _selectedFarm = null),
                ),
              ),
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

  bool _selectedFarmIsShowingListHidden() {
    return _showFarmList || (_selectedFarm != null && !_showFarmList);
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.farmCount,
    required this.onBack,
    required this.onLocate,
    required this.onRefresh,
    required this.isLocating,
  });

  final int farmCount;
  final VoidCallback? onBack;
  final VoidCallback onLocate;
  final Future<void> Function() onRefresh;
  final bool isLocating;

  @override
  Widget build(BuildContext context) {
    final title =
        farmCount == 0 ? 'Sin fincas ubicadas' : '$farmCount fincas en el mapa';

    return Row(
      children: [
        if (onBack != null) ...[
          _MapIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack!,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x123E2F25),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: AppColors.clayStrong,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ConnectedActionGroup(
          isLocating: isLocating,
          onLocate: onLocate,
          onRefresh: onRefresh,
        ),
      ],
    );
  }
}

class _ConnectedActionGroup extends StatelessWidget {
  const _ConnectedActionGroup({
    required this.isLocating,
    required this.onLocate,
    required this.onRefresh,
  });

  final bool isLocating;
  final VoidCallback onLocate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x123E2F25),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _ConnectedActionButton(
            icon: isLocating ? Icons.more_horiz_rounded : Icons.my_location_rounded,
            onTap: onLocate,
            leftRounded: true,
          ),
          Container(
            width: 0.5,
            height: 26,
            color: AppColors.sand,
          ),
          _ConnectedActionButton(
            icon: Icons.refresh_rounded,
            onTap: () => onRefresh(),
            rightRounded: true,
          ),
        ],
      ),
    );
  }
}

class _ConnectedActionButton extends StatelessWidget {
  const _ConnectedActionButton({
    required this.icon,
    required this.onTap,
    this.leftRounded = false,
    this.rightRounded = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool leftRounded;
  final bool rightRounded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(leftRounded ? 999 : 0),
          right: Radius.circular(rightRounded ? 999 : 0),
        ),
        child: SizedBox(
          width: 52,
          height: 48,
          child: Icon(icon, color: AppColors.clayStrong),
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.clayStrong),
        ),
      ),
    );
  }
}

class _ListFarmButton extends StatelessWidget {
  const _ListFarmButton({
    required this.isOpen,
    required this.onTap,
  });

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.soil,
        foregroundColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      icon: Icon(isOpen ? Icons.close_rounded : Icons.format_list_bulleted_rounded),
      label: Text(isOpen ? 'Cerrar listado' : 'Ver mis fincas'),
    );
  }
}

class _FarmListSheet extends StatelessWidget {
  const _FarmListSheet({
    required this.farms,
    required this.onSelectFarm,
    required this.onClose,
  });

  final List<Map<String, dynamic>> farms;
  final void Function(Map<String, dynamic>) onSelectFarm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.24,
      maxChildSize: 0.82,
      snap: true,
      snapSizes: const [0.24, 0.34, 0.55, 0.82],
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis fincas',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Toca una para centrar el mapa',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SoftCircleButton(
                    icon: Icons.close_rounded,
                    onTap: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (farms.isEmpty)
                const Expanded(
                  child: _CenteredEmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'Aún no tienes fincas registradas',
                    subtitle: '',
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: farms.length,
                    separatorBuilder: (context, index) => Divider(
                      color: AppColors.sand.withValues(alpha: 0.7),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final farm = farms[index];
                      final hasCoordinates = farm['has_coordinates'] == true;
                      final location =
                          (farm['ubicacion_texto'] ?? 'Sin ubicación').toString();
                      final areaText = _formatArea(farm['area_hectareas']);

                      return ListTile(
                        enabled: hasCoordinates,
                        onTap: () => onSelectFarm(farm),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: hasCoordinates
                                ? AppColors.backgroundSoft
                                : AppColors.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: hasCoordinates
                                ? AppColors.moss
                                : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          (farm['nombre'] ?? 'Finca').toString(),
                          style: TextStyle(
                            color: hasCoordinates
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        trailing: hasCoordinates
                            ? _InfoBadge(
                                text: areaText.isEmpty
                                    ? 'Área pendiente'
                                    : '$areaText ha',
                              )
                            : const _MutedBadge(text: 'Sin ubicación'),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _formatArea(dynamic value) {
    final parsed = DatabaseHelper.toDouble(value);
    if (parsed == null) {
      return '';
    }
    return parsed % 1 == 0 ? parsed.toStringAsFixed(0) : parsed.toStringAsFixed(1);
  }
}

class _FarmDetailSheet extends StatelessWidget {
  const _FarmDetailSheet({
    required this.farm,
    required this.onOpenLots,
    required this.onOpenCosechas,
    required this.onEditLocation,
    required this.onClose,
  });

  final Map<String, dynamic> farm;
  final VoidCallback onOpenLots;
  final VoidCallback onOpenCosechas;
  final VoidCallback onEditLocation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final areaText = _FarmListSheet._formatArea(farm['area_hectareas']);
    final lotesCount = DatabaseHelper.toInt(farm['lotes_count']) ?? 0;
    final cosechasCount = DatabaseHelper.toInt(farm['cosechas_current_year']) ?? 0;
    final currentYear = DateTime.now().year;

    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.22,
      maxChildSize: 0.72,
      snap: true,
      snapSizes: const [0.22, 0.30, 0.5, 0.72],
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.sand),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
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
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (farm['nombre'] ?? 'Finca').toString(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (farm['ubicacion_texto'] ?? 'Sin ubicación registrada')
                                .toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SoftCircleButton(
                      icon: Icons.close_rounded,
                      onTap: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoBadge(
                      text: areaText.isEmpty ? 'Área pendiente' : '$areaText ha',
                    ),
                    _InfoBadge(text: '$lotesCount lotes'),
                    _InfoBadge(text: '$cosechasCount cosechas $currentYear'),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.sand.withValues(alpha: 0.8), height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCardButton(
                        icon: Icons.grid_view_rounded,
                        title: 'Lotes',
                        count: lotesCount,
                        filled: true,
                        onTap: onOpenLots,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCardButton(
                        icon: Icons.agriculture_rounded,
                        title: 'Cosechas',
                        count: cosechasCount,
                        filled: false,
                        onTap: onOpenCosechas,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onEditLocation,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.clayStrong,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.edit_location_alt_rounded),
                    label: const Text('Editar ubicación de la finca'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionCardButton extends StatelessWidget {
  const _ActionCardButton({
    required this.icon,
    required this.title,
    required this.count,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = filled ? AppColors.moss : AppColors.surface;
    final foregroundColor = filled ? AppColors.surface : AppColors.clayStrong;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: filled ? null : Border.all(color: AppColors.sand),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foregroundColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _CountBadge(
                count: count,
                filled: filled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.filled,
  });

  final int count;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled
            ? AppColors.surface.withValues(alpha: 0.16)
            : AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: filled ? AppColors.surface : AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniMapAction extends StatelessWidget {
  const _MiniMapAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.clayStrong,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppColors.sand),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _FarmMarker extends StatelessWidget {
  const _FarmMarker({
    required this.label,
    required this.isSelected,
  });

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final markerColor = isSelected ? AppColors.moss : AppColors.clayStrong;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: isSelected ? 1.12 : 1,
          child: CustomPaint(
            painter: _PinPainter(color: markerColor),
            child: SizedBox(
              width: 36,
              height: 44,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 9),
                  child: Icon(
                    Icons.home_rounded,
                    color: AppColors.surface,
                    size: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final shadowPaint = Paint()..color = const Color(0x1F3E2F25);

    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..quadraticBezierTo(0, size.height * 0.72, 0, size.height * 0.34)
      ..arcToPoint(
        Offset(size.width, size.height * 0.34),
        radius: Radius.circular(size.width / 2),
      )
      ..quadraticBezierTo(
        size.width,
        size.height * 0.72,
        size.width / 2,
        size.height,
      )
      ..close();

    canvas.drawShadow(path, shadowPaint.color, 8, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MapStateCard extends StatelessWidget {
  const _MapStateCard({
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
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CircularProgressIndicator(color: AppColors.moss)
          else
            Icon(icon, size: 42, color: AppColors.clayStrong),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
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

class _CenteredEmptyState extends StatelessWidget {
  const _CenteredEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.clayStrong, size: 42),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MutedBadge extends StatelessWidget {
  const _MutedBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SoftCircleButton extends StatelessWidget {
  const _SoftCircleButton({
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
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: AppColors.soil),
        ),
      ),
    );
  }
}
