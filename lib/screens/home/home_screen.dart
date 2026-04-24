import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/auth/auth_service.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/shared/pending_sync_service.dart';
import 'package:app_flutter_ai/core/services/shared/sync_service.dart';
import 'package:app_flutter_ai/layout/app_bottom_nav_bar.dart';
import 'package:app_flutter_ai/screens/export/export_screen.dart';
import 'package:app_flutter_ai/screens/fincas/farm_list_screen.dart';
import 'package:app_flutter_ai/screens/fincas/farm_map_screen.dart';
import 'package:app_flutter_ai/screens/profile/profile_screen.dart';
import 'package:app_flutter_ai/screens/shared/pending_sync_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _syncSeed = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    PendingSyncService.refreshPendingCount();
  }

  static const _navItems = [
    AppBottomNavItem(icon: Icons.agriculture_rounded, label: 'Fincas'),
    AppBottomNavItem(icon: Icons.map_outlined, label: 'Mapa'),
    AppBottomNavItem(icon: Icons.file_download_outlined, label: 'Exportar'),
    AppBottomNavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  Future<void> _syncNow() async {
    if (_isSyncing) {
      return;
    }

    setState(() => _isSyncing = true);

    final pendingCount = PendingSyncService.pendingCount.value;
    int? remainingAfterSync;
    var snackBarColor = AppColors.success;
    var message =
        'Sincronización revisada. La aplicación conservó los datos locales cuando no era necesario repetir llamadas.';

    try {
      switch (_currentIndex) {
        case 0:
        case 1:
          if (pendingCount > 0) {
            await SyncService.syncPendingChanges();
            remainingAfterSync = PendingSyncService.pendingCount.value;
            message = remainingAfterSync <= 0
                ? 'La cola de cambios pendientes se sincronizó correctamente.'
                : 'Se subieron varios cambios, pero aún quedan $remainingAfterSync pendientes por revisar.';
          } else {
            message = 'No hay cambios pendientes por sincronizar.';
          }
          break;
        case 2:
          await SyncService.syncAll();
          remainingAfterSync = PendingSyncService.pendingCount.value;
          message = remainingAfterSync <= 0
              ? 'La información se sincronizó para exportación.'
              : 'La exportación actualizó datos, pero aún quedan $remainingAfterSync cambios pendientes.';
          break;
        case 3:
          if (pendingCount > 0) {
            await SyncService.syncPendingChanges();
            remainingAfterSync = PendingSyncService.pendingCount.value;
            message = remainingAfterSync <= 0
                ? 'La cola de cambios pendientes se sincronizó correctamente.'
                : 'Se subieron varios cambios, pero aún quedan $remainingAfterSync pendientes por revisar.';
          } else {
            message =
                'El perfil usa primero los datos guardados en la sesión. Desliza hacia abajo para consultar el perfil remoto.';
          }
          break;
      }

      if (!mounted) {
        return;
      }

      final syncIssue = SyncService.lastIssueMessage;
      if (syncIssue != null && syncIssue.trim().isNotEmpty) {
        snackBarColor = AppColors.clayStrong;
        message = syncIssue;
        remainingAfterSync = PendingSyncService.pendingCount.value;
      }

      if (!SessionService.canRestoreSession || AuthService.hasInvalidSession) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu sesión ya no es válida. Inicia sesión nuevamente.',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      setState(() {
        _syncSeed++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: snackBarColor,
          behavior: SnackBarBehavior.floating,
          action: remainingAfterSync != null && remainingAfterSync > 0
              ? SnackBarAction(
                  label: 'Ver',
                  textColor: AppColors.surface,
                  onPressed: _openPendingSyncScreen,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _openPendingSyncScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PendingSyncScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _syncSeed++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildTab(),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: PendingSyncService.pendingCount,
        builder: (context, pendingCount, child) {
          return AppBottomNavBar(
            items: _navItems,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            onSync: _syncNow,
            isSyncing: _isSyncing,
            pendingCount: pendingCount,
          );
        },
      ),
    );
  }

  Widget _buildTab() {
    switch (_currentIndex) {
      case 1:
        return FarmMapScreen(
          key: ValueKey('home-map-$_syncSeed'),
          embedded: true,
          onGoToFincas: () => setState(() => _currentIndex = 0),
        );
      case 2:
        return ExportScreen(
          key: ValueKey('home-export-$_syncSeed'),
        );
      case 3:
        return ProfileScreen(
          key: ValueKey('home-profile-$_syncSeed'),
        );
      case 0:
      default:
        return FarmListScreen(
          key: ValueKey('home-farms-$_syncSeed'),
          embedded: true,
        );
    }
  }
}
