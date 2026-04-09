import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/layout/app_bottom_nav_bar.dart';
import 'package:app_flutter_ai/screens/farms/farm_map_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _navItems = [
    AppBottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
    AppBottomNavItem(icon: Icons.map_outlined, label: 'Campo'),
    AppBottomNavItem(icon: Icons.smart_toy_rounded, label: 'IA'),
    AppBottomNavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.backgroundSoft,
              AppColors.surfaceMuted,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
            child: _buildTab(),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        items: _navItems,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget _buildTab() {
    switch (_currentIndex) {
      case 1:
        return const _PlaceholderTab(
          title: 'Campo',
          subtitle:
              'Aqui luego puedes mostrar informacion del campo, recorridos o modulos relacionados.',
          icon: Icons.agriculture_rounded,
        );
      case 2:
        return const _PlaceholderTab(
          title: 'IA',
          subtitle:
              'Aqui luego puedes reunir funciones de IA, historial o accesos rapidos.',
          icon: Icons.psychology_alt_rounded,
        );
      case 3:
        return _PlaceholderTab(
          title: 'Perfil',
          subtitle:
              'Este espacio queda libre para configuracion, perfil y cierre de sesion.',
          icon: Icons.person_rounded,
          actionLabel: 'Cerrar sesion',
          onAction: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          ),
        );
      case 0:
      default:
        return const _HomeMenuTab();
    }
  }
}

class _HomeMenuTab extends StatelessWidget {
  const _HomeMenuTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.surfaceMuted, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A3E2F25),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inicio',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Selecciona un modulo para continuar.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.76,
            physics: const BouncingScrollPhysics(),
            children: [
              _MenuCard(
                title: 'Gestiona fincas',
                subtitle: 'Consulta tus fincas y agrega nuevos registros',
                icon: Icons.home_work_rounded,
                onTap: () => Navigator.pushNamed(context, '/farms'),
              ),
              _MenuCard(
                title: 'Mapa de fincas',
                subtitle: 'Explora visualmente todas tus fincas en el mapa',
                icon: Icons.map_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FarmMapScreen(),
                    ),
                  );
                },
              ),
              _MenuCard(
                title: 'Tareas por IA',
                subtitle: 'Registra actividades del campo con IA local',
                icon: Icons.psychology_alt_rounded,
                onTap: () => Navigator.pushNamed(context, '/dashboard'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      splashColor: AppColors.sand.withValues(alpha: 0.3),
      highlightColor: Colors.transparent,
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.surfaceMuted, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A3E2F25),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.clayStrong, size: 24),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceMuted, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3E2F25),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppColors.clayStrong, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.clayStrong,
                  foregroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
