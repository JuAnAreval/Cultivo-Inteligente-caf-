import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/finca_service.dart';
import 'package:app_flutter_ai/core/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FarmMapScreen extends StatefulWidget {
  const FarmMapScreen({super.key});

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen> {
  static const LatLng _defaultCenter = LatLng(4.5709, -74.2973);

  final MapController _mapController = MapController();
  late Future<List<Map<String, dynamic>>> _farmsFuture;

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
    setState(() {
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
      final lat = _parseCoordinate(farms.first['latitud']);
      final lng = _parseCoordinate(farms.first['longitud']);
      if (lat != null && lng != null) {
        _mapController.move(LatLng(lat, lng), 14);
      }
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
        padding: const EdgeInsets.fromLTRB(56, 120, 56, 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
                return Marker(
                  point: LatLng(lat, lng),
                  width: 120,
                  height: 72,
                  child: _FarmMapMarker(
                    name: (farm['nombre'] ?? 'Finca').toString(),
                  ),
                );
              })
              .whereType<Marker>()
              .toList();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && snapshot.connectionState == ConnectionState.done) {
              _focusAllFarms(farms);
            }
          });

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 6.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.appflutterai.app_flutter_ai',
                  ),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      _TopOverlay(
                        farmCount: farms.length,
                        onBack: () => Navigator.pop(context),
                        onRefresh: _refresh,
                      ),
                      const Spacer(),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const _StatusCard(
                          icon: Icons.public_rounded,
                          title: 'Cargando fincas',
                          subtitle: 'Estamos ubicando tus registros en el mapa.',
                          loading: true,
                        )
                      else if (snapshot.hasError)
                        _StatusCard(
                          icon: Icons.error_outline_rounded,
                          title: 'No se pudo cargar el mapa',
                          subtitle: snapshot.error.toString(),
                          actionLabel: 'Reintentar',
                          onAction: _refresh,
                        )
                      else if (farms.isEmpty)
                        const _StatusCard(
                          icon: Icons.home_work_outlined,
                          title: 'Aun no hay fincas para mostrar',
                          subtitle:
                              'Cuando registres fincas con coordenadas, apareceran aqui sobre el mapa.',
                        )
                      else
                        _BottomSheetCard(
                          farms: farms,
                          onManageFarms: () {
                            Navigator.pushNamed(context, '/farms');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.farmCount,
    required this.onBack,
    required this.onRefresh,
  });

  final int farmCount;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleMapButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                        '$farmCount ubicaciones visibles',
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
          icon: Icons.refresh_rounded,
          onTap: () {
            onRefresh();
          },
        ),
      ],
    );
  }
}

class _BottomSheetCard extends StatelessWidget {
  const _BottomSheetCard({
    required this.farms,
    required this.onManageFarms,
  });

  final List<Map<String, dynamic>> farms;
  final VoidCallback onManageFarms;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
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
            children: [
              const Expanded(
                child: Text(
                  'Tus fincas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onManageFarms,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.moss,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'Gestionar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: farms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final farm = farms[index];
                final area = (farm['area_hectareas'] ?? '').toString();
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
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
                              (farm['ubicacion_texto'] ?? 'Sin ubicacion')
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
                            '$area ha',
                            style: const TextStyle(
                              color: AppColors.soil,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
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
        color: AppColors.surface.withValues(alpha: 0.95),
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

class _FarmMapMarker extends StatelessWidget {
  const _FarmMapMarker({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x143E2F25),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.soil,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Icon(
          Icons.location_on_rounded,
          color: AppColors.clayStrong,
          size: 34,
        ),
      ],
    );
  }
}
