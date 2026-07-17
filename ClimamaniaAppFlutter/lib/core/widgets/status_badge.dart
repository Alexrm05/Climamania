import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// Tono semántico de una etiqueta de estado.
enum BadgeTone { neutral, success, warning, danger, info, brand }

/// Píldora de estado reutilizable (radio pill + labelMedium). Puede ser
/// sólida (fondo de color, texto blanco) o suave (tinte de fondo, texto color).
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final bool solid;
  final IconData? icon;

  const StatusBadge(
    this.label, {
    super.key,
    this.tone = BadgeTone.neutral,
    this.solid = false,
    this.icon,
  });

  ({Color fg, Color tint}) get _c => switch (tone) {
        BadgeTone.success => (fg: AppColors.successFg, tint: AppColors.successTint),
        BadgeTone.warning => (fg: AppColors.warningFg, tint: AppColors.warningTint),
        BadgeTone.danger => (fg: AppColors.errorFg, tint: AppColors.errorTint),
        BadgeTone.info => (fg: AppColors.infoFg, tint: AppColors.infoTint),
        BadgeTone.brand => (fg: AppColors.primary, tint: AppColors.footerActiveBg),
        BadgeTone.neutral => (fg: AppColors.textSecondary, tint: AppColors.surfaceWarm),
      };

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final bg = solid ? c.fg : c.tint;
    final fg = solid ? AppColors.white : c.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brPill,
        border: solid ? null : Border.all(color: c.fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
