import 'dart:ui';

import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/auth/auth_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isRecoveringPassword = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(
        'Completa correo y contraseña para continuar.',
        AppColors.clayStrong,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.login(email, password);
      if (!mounted) {
        return;
      }

      if (response['success'] == true) {
        _showSnackBar('Ingreso exitoso.', AppColors.success);
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      _showSnackBar(
        response['message']?.toString() ?? 'No fue posible iniciar sesión.',
        AppColors.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Ocurrió un error al iniciar sesión: $error',
        AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar(
        'Escribe tu correo para enviarte el enlace de recuperación.',
        AppColors.clayStrong,
      );
      return;
    }

    setState(() => _isRecoveringPassword = true);
    try {
      final response = await AuthService.forgotPassword(email);
      if (!mounted) {
        return;
      }

      _showSnackBar(
        response['message']?.toString() ??
            'Revisa tu correo para continuar con el cambio de contraseña.',
        response['success'] == true ? AppColors.success : AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isRecoveringPassword = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Stack(
          children: [
            Positioned(
              top: 50,
              left: -40,
              child: _Blob(
                size: 200,
                color: AppColors.sage.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              top: -20,
              right: -30,
              child: _Blob(
                size: 240,
                color: AppColors.clay.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              bottom: 80,
              left: 20,
              child: _Blob(
                size: 180,
                color: AppColors.sand.withValues(alpha: 0.4),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: AppColors.surface.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A3E2F25),
                                blurRadius: 30,
                                offset: Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.clay.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'App de campo',
                                  style: TextStyle(
                                    color: AppColors.clayStrong,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Bienvenido',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.8,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Inicia sesión para continuar.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 36),
                              _InputField(
                                controller: _emailController,
                                label: 'Correo electrónico',
                                hint: 'tu@empresa.com',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 20),
                              _InputField(
                                controller: _passwordController,
                                label: 'Contraseña',
                                hint: 'Escribe tu contraseña',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  splashRadius: 24,
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      key: ValueKey(_obscurePassword),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading || _isRecoveringPassword
                                      ? null
                                      : _forgotPassword,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.clayStrong,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: _isRecoveringPassword
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.clayStrong,
                                          ),
                                        )
                                      : const Text(
                                          'Olvidé mi contraseña',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.clayStrong,
                                    foregroundColor: AppColors.surface,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.surface,
                                          ),
                                        )
                                      : const Text(
                                          'Entrar al inicio',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.7),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.clay, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.4),
      ),
    );
  }
}
