import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:flutter/material.dart';

AppBar buildCultivaSecondaryAppBar({
  required BuildContext context,
  required String title,
  List<Widget>? actions,
  Widget? leading,
}) {
  return AppBar(
    centerTitle: true,
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: leading,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    actions: actions,
  );
}

class CultivaHeroCard extends StatelessWidget {
  const CultivaHeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        color: AppColors.clayStrong,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    );
  }
}

class CultivaEntityCard extends StatelessWidget {
  const CultivaEntityCard({
    super.key,
    required this.accentColor,
    required this.child,
    this.onTap,
  });

  final Color accentColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.sand),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          children: [
            Container(
              width: 4,
              color: accentColor,
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: child,
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

class CultivaTintedChip extends StatelessWidget {
  const CultivaTintedChip({
    super.key,
    required this.icon,
    required this.label,
    this.backgroundColor = AppColors.backgroundSoft,
    this.foregroundColor = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class CultivaStatusBadge extends StatelessWidget {
  const CultivaStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class CultivaMiniStat extends StatelessWidget {
  const CultivaMiniStat({
    super.key,
    required this.value,
    required this.label,
    this.alignment = CrossAxisAlignment.start,
  });

  final String value;
  final String label;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class CultivaEmptyStateCard extends StatelessWidget {
  const CultivaEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.backgroundSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.moss, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class CultivaPillFab extends StatelessWidget {
  const CultivaPillFab({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.moss,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: AppColors.surface,
      elevation: 2,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String formatSpanishDate(String rawDate) {
  final match = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(rawDate);
  final normalized = match?.group(0) ?? rawDate.trim();
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) {
    return rawDate;
  }

  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  return '${parsed.day} de ${months[parsed.month - 1]}, ${parsed.year}';
}
