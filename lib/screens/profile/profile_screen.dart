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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _identificationController =
      TextEditingController();
  final TextEditingController _socialMediaController = TextEditingController();

  Map<String, dynamic> _profile = <String, dynamic>{};
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _identificationController.dispose();
    _socialMediaController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool remote = false}) async {
    if (!_isEditing) {
      setState(() => _isLoading = true);
    }

    try {
      final profile = await ProfileService.getProfile(remote: remote);
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      _fillControllers(profile);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showSnackBar(
        'No fue posible cargar el perfil: $error',
        AppColors.danger,
      );
    }
  }

  void _fillControllers(Map<String, dynamic> profile) {
    _nameController.text = (profile['displayName'] ?? '').toString();
    _emailController.text = (profile['email'] ?? '').toString();
    _phoneController.text = (profile['phone'] ?? '').toString();
    _addressController.text = (profile['address'] ?? '').toString();
    _identificationController.text =
        (profile['identification'] ?? '').toString();
    _socialMediaController.text = (profile['socialMedia'] ?? '').toString();
  }

  Future<void> _reload() async {
    await _loadProfile(remote: true);
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      _showSnackBar(
        'Nombre y correo son obligatorios para guardar el perfil.',
        AppColors.clayStrong,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await ProfileService.updateProfile(
        displayName: name,
        email: email,
        phone: _phoneController.text,
        address: _addressController.text,
        identification: _identificationController.text,
        socialMedia: _socialMediaController.text,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = updated;
        _isEditing = false;
        _isSaving = false;
      });
      _fillControllers(updated);
      _showSnackBar('Perfil actualizado correctamente.', AppColors.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _showSnackBar(
        'No fue posible actualizar el perfil: $error',
        AppColors.danger,
      );
    }
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
    _fillControllers(_profile);
  }

  Future<void> _logout() async {
    await SessionService.clear();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = (profile['displayName'] ?? 'Usuario de campo').toString();
    final role = (profile['roleName'] ?? 'Administrador de fincas').toString();
    final company = (profile['companyName'] ?? 'Dato Rural').toString();
    final email = (profile['email'] ?? '').toString();
    final phone = (profile['phone'] ?? '').toString();
    final address = (profile['address'] ?? '').toString();
    final identification = (profile['identification'] ?? '').toString();
    final socialMedia = (profile['socialMedia'] ?? '').toString();

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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.moss),
              )
            : RefreshIndicator(
                onRefresh: _reload,
                color: AppColors.moss,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 132),
                  children: [
                    _ProfileHeroCard(
                      name: name,
                      role: role,
                      company: company,
                      isEditing: _isEditing,
                      onEdit: () {
                        setState(() => _isEditing = true);
                      },
                    ),
                    const SizedBox(height: 18),
                    if (_isEditing)
                      _EditableProfileCard(
                        nameController: _nameController,
                        emailController: _emailController,
                        phoneController: _phoneController,
                        addressController: _addressController,
                        identificationController: _identificationController,
                        socialMediaController: _socialMediaController,
                        isSaving: _isSaving,
                        onCancel: _cancelEdit,
                        onSave: _saveProfile,
                      )
                    else
                      _ProfileOverviewCard(
                        email: email,
                        phone: phone,
                        address: address,
                        identification: identification,
                        socialMedia: socialMedia,
                      ),
                    const SizedBox(height: 18),
                    _ProfileActionsCard(
                      onLogout: _logout,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.name,
    required this.role,
    required this.company,
    required this.isEditing,
    required this.onEdit,
  });

  final String name;
  final String role;
  final String company;
  final bool isEditing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.sand),
        boxShadow: const [
          BoxShadow(
            color: Color(0x123E2F25),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfileAvatar(name: name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      role,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company,
                      style: const TextStyle(
                        color: AppColors.clayStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    isEditing ? 'Editando perfil' : 'Perfil de Cultiva Tec',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (!isEditing) ...[
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.clayStrong,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableProfileCard extends StatelessWidget {
  const _EditableProfileCard({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.identificationController,
    required this.socialMediaController,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController identificationController;
  final TextEditingController socialMediaController;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Editar información',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _ProfileField(
            controller: nameController,
            label: 'Nombre completo',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _ProfileField(
            controller: emailController,
            label: 'Correo',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _ProfileField(
            controller: phoneController,
            label: 'Teléfono',
            icon: Icons.call_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _ProfileField(
            controller: addressController,
            label: 'Dirección',
            icon: Icons.location_on_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          _ProfileField(
            controller: identificationController,
            label: 'Identificación',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _ProfileField(
            controller: socialMediaController,
            label: 'Red social o enlace',
            icon: Icons.public_rounded,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.soil,
                    side: const BorderSide(color: AppColors.sand),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.moss,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(isSaving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileOverviewCard extends StatelessWidget {
  const _ProfileOverviewCard({
    required this.email,
    required this.phone,
    required this.address,
    required this.identification,
    required this.socialMedia,
  });

  final String email;
  final String phone;
  final String address;
  final String identification;
  final String socialMedia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información personal',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Correo',
            value: email.isEmpty ? 'No registrado' : email,
          ),
          _InfoRow(
            icon: Icons.call_outlined,
            label: 'Teléfono',
            value: phone.isEmpty ? 'No registrado' : phone,
          ),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Dirección',
            value: address.isEmpty ? 'No registrada' : address,
          ),
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Identificación',
            value: identification.isEmpty ? 'No registrada' : identification,
          ),
          _InfoRow(
            icon: Icons.public_rounded,
            label: 'Red social',
            value: socialMedia.isEmpty ? 'No registrada' : socialMedia,
          ),
        ],
      ),
    );
  }
}

class _ProfileActionsCard extends StatelessWidget {
  const _ProfileActionsCard({
    required this.onLogout,
  });

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.soil,
                side: const BorderSide(color: AppColors.sand),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
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
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            AppColors.clayStrong,
            AppColors.clay,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          parts.isEmpty ? 'U' : parts,
          style: const TextStyle(
            color: AppColors.surface,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.backgroundSoft,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
            child: Icon(icon, color: AppColors.clayStrong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
