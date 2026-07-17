import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Pantalla provisional "Próximamente / En construcción".
/// - Como rama del shell ([standalone] = false): solo el contenido centrado.
/// - Empujada de forma independiente ([standalone] = true): con AppBar y volver.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final bool standalone;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final content = Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.footerActiveBg,
              borderRadius: AppRadius.brLg,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  width: 1.5),
            ),
            child: const Icon(Icons.construction_rounded,
                size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Estamos trabajando en esta sección. Estará disponible próximamente.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );

    if (!standalone) return content;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: content,
    );
  }
}
