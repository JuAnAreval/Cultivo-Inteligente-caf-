import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/profile/profile_service.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileService.getProfile();
  }

  Future<void> _reload() async {
    setState(() {
      _profileFuture = ProfileService.getProfile(remote: true);
    });
    await _profileFuture;
  }

  Future<void> _logout() async {
    await SessionService.clear();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
        bottom: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.moss),
              );
            }

            final profile = snapshot.data ?? <String, dynamic>{};
            final name = (profile['displayName'] ?? 'Usuario de campo').toString();
            final role = (profile['roleName'] ?? 'Administrador de fincas').toString();
            final company = (profile['companyName'] ?? 'Dato Rural').toString();
            final email = (profile['email'] ?? '').toString();
            final phone = (profile['phone'] ?? '').toString();
            final address = (profile['address'] ?? '').toString();
            final identification = (profile['identification'] ?? '').toString();
            final socialMedia = (profile['socialMedia'] ?? '').toString();

            return RefreshIndicator(
              onRefresh: _reload,
              color: AppColors.moss,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.sand),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F3E2F25),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _ProfileAvatar(name: name),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          role,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SectionTitle('Información de contacto'),
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.mail_outline_rounded,
                          title: email.isEmpty ? 'Correo no disponible' : email,
                        ),
                        _InfoTile(
                          icon: Icons.call_outlined,
                          title: phone.isEmpty ? 'Teléfono no registrado' : phone,
                        ),
                        _InfoTile(
                          icon: Icons.location_on_outlined,
                          title: address.isEmpty ? 'Dirección no registrada' : address,
                        ),
                        const Divider(height: 30, color: AppColors.surfaceMuted),
                        _SectionTitle('Detalles de la cuenta'),
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.apartment_rounded,
                          title: 'Organización: $company',
                        ),
                        _InfoTile(
                          icon: Icons.badge_outlined,
                          title: identification.isEmpty
                              ? 'Identificación no registrada'
                              : 'Identificación: $identification',
                        ),
                        if (socialMedia.isNotEmpty)
                          _InfoTile(
                            icon: Icons.public_rounded,
                            title: socialMedia,
                          ),
                        const Divider(height: 30, color: AppColors.surfaceMuted),
                        _SectionTitle('Configuración'),
                        const SizedBox(height: 12),
                        const _ActionTile(
                          icon: Icons.tune_rounded,
                          title: 'Configuración general',
                          subtitle: 'Preferencias y ajustes visuales',
                        ),
                        const _ActionTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'Seguridad y contraseña',
                          subtitle: 'Protección de acceso y sesión',
                        ),
                        const _ActionTile(
                          icon: Icons.help_outline_rounded,
                          title: 'Ayuda y soporte',
                          subtitle: 'Guías de uso y contacto',
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _reload,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.clayStrong,
                              foregroundColor: AppColors.surface,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text(
                              'Actualizar perfil',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.soil,
                              backgroundColor: AppColors.backgroundSoft,
                              side: const BorderSide(color: AppColors.sand),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();

    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            AppColors.clayStrong,
            AppColors.clay,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x223E2F25),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          parts.isEmpty ? 'U' : parts,
          style: const TextStyle(
            color: AppColors.surface,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.clayStrong, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.soil),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
