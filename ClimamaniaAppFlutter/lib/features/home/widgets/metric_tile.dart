import 'package:flutter/material.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_spacing.dart';

enum MetricTone { success, danger }

/// Tarjeta compacta de resumen (Visitas / Incidencias) pensada para ir en
/// pareja, una al lado de la otra. Fondo con tinte semántico (verde / rojo)
/// y el número de pendientes en grande.
class MetricTile extends StatelessWidget {
  final MetricTone tone;
  final IconData icon;
  final String label;
  final int count; // -1 = cargando
  final bool error;
  final VoidCallback onTap;

  const MetricTile({
    super.key,
    required this.tone,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bool ok = tone == MetricTone.success;
    final Color fg = ok ? AppColors.successFg : AppColors.errorFg;
    final Color tint = ok ? AppColors.successTint : AppColors.errorTint;
    final bool loading = count < 0 && !error;
    final bool hasPend = count > 0;

    final String subtitle = error
        ? 'No disponible'
        : hasPend
            ? (count == 1 ? 'pendiente' : 'pendientes')
            : 'Sin pendientes';

    return Material(
      color: tint,
      borderRadius: AppRadius.brLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: Ink(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: AppRadius.brLg,
            border: Border.all(color: fg.withValues(alpha: 0.22)),
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Icon(icon, color: AppColors.white, size: 22),
                  ),
                  Icon(Icons.chevron_right,
                      color: fg.withValues(alpha: 0.55), size: 20),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: loading
                      ? const SkeletonBox(width: 44, height: 30)
                      : Text(
                          error ? '—' : '$count',
                          style: t.displaySmall?.copyWith(
                            height: 1.0,
                            color: fg,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: t.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
