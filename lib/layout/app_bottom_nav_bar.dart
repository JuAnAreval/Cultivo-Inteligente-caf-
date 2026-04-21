import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:flutter/material.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onSync,
    this.isSyncing = false,
    this.pendingCount = 0,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onSync;
  final bool isSyncing;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.soil,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x333E2F25),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _BottomNavButton(
                  item: items[index],
                  selected: index == currentIndex,
                  onTap: () => onTap(index),
                ),
              ),
            if (onSync != null) ...[
              Container(
                width: 1,
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: AppColors.clay.withValues(alpha: 0.28),
              ),
              _SyncNavButton(
                isSyncing: isSyncing,
                pendingCount: pendingCount,
                onTap: isSyncing ? null : onSync,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: AppColors.clay.withValues(alpha: 0.2),
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 64,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.clay : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: selected ? 1.0 : 0.96,
                child: Icon(
                  item.icon,
                  color: selected ? AppColors.surface : AppColors.sand,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: selected ? AppColors.surface : AppColors.sand,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: selected ? 0.2 : 0,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncNavButton extends StatefulWidget {
  const _SyncNavButton({
    required this.isSyncing,
    required this.pendingCount,
    required this.onTap,
  });

  final bool isSyncing;
  final int pendingCount;
  final VoidCallback? onTap;

  @override
  State<_SyncNavButton> createState() => _SyncNavButtonState();
}

class _SyncNavButtonState extends State<_SyncNavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _syncPulseState();
  }

  @override
  void didUpdateWidget(covariant _SyncNavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingCount != widget.pendingCount ||
        oldWidget.isSyncing != widget.isSyncing) {
      _syncPulseState();
    }
  }

  void _syncPulseState() {
    final shouldPulse = widget.pendingCount > 0 && !widget.isSyncing;
    if (shouldPulse) {
      _pulseController.repeat(reverse: true);
      return;
    }

    _pulseController.stop();
    _pulseController.value = 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = widget.pendingCount > 0;
    final badgeText = widget.pendingCount > 99
        ? '99+'
        : widget.pendingCount.toString();

    return Tooltip(
      message: widget.isSyncing
          ? 'Sincronizando'
          : hasPending
          ? '${widget.pendingCount} cambios pendientes'
          : 'Sincronizar',
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = hasPending && !widget.isSyncing
              ? 1 + (_pulseController.value * 0.08)
              : 1.0;

          return Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: widget.isSyncing
                      ? AppColors.clay.withValues(alpha: 0.94)
                      : hasPending
                      ? AppColors.moss.withValues(alpha: 0.22)
                      : AppColors.clay.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: widget.isSyncing
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppColors.surface,
                                )
                              : Icon(
                                  Icons.sync_rounded,
                                  color: hasPending
                                      ? AppColors.moss
                                      : AppColors.sand,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  top: hasPending ? -6 : 6,
                  right: hasPending ? -6 : 6,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: hasPending ? 1 : 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.clayStrong,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x223E2F25),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
