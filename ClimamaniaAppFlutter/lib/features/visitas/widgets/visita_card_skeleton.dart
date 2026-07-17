import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';

/// Placeholder de carga con la misma forma que [VisitaCard], para que al llegar
/// los datos no haya salto de layout.
class VisitaCardSkeleton extends StatelessWidget {
  const VisitaCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: AppDecorations.whiteCard,
        child: ClipRRect(
          borderRadius: AppRadius.brLg,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // cabecera: estado + Nº
                Row(
                  children: [
                    SkeletonBox(
                        width: 130, height: 22, radius: AppRadius.brPill),
                    const Spacer(),
                    SkeletonBox(width: 64, height: 22, radius: AppRadius.brPill),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // identidad: azulejo + nombre + badge
                Row(
                  children: [
                    SkeletonBox(width: 44, height: 44, radius: AppRadius.brMd),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 170, height: 16),
                          const SizedBox(height: AppSpacing.xs),
                          SkeletonBox(
                              width: 72, height: 18, radius: AppRadius.brPill),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                    height: 1, width: double.infinity, color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                // dirección
                Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: AppRadius.brMd),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                        child: SkeletonBox(width: double.infinity, height: 14)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Padding(
                  padding: EdgeInsets.only(left: 48),
                  child: SkeletonBox(width: 180, height: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                // acciones
                Row(
                  children: [
                    Expanded(
                        child: SkeletonBox(
                            width: double.infinity,
                            height: 44,
                            radius: AppRadius.brPill)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: SkeletonBox(
                            width: double.infinity,
                            height: 44,
                            radius: AppRadius.brPill)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: SkeletonBox(
                            width: double.infinity,
                            height: 44,
                            radius: AppRadius.brPill)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
