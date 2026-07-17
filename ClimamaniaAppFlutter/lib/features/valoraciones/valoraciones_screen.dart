import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/status_badge.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Pantalla de Valoraciones (rama /ratings): cabecera hero, tarjeta con el QR
/// oficial y pasos.
class ValoracionesScreen extends StatelessWidget {
  const ValoracionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textSecondary);

    return Container(
      color: AppColors.primaryLight,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Hero: icono + título + badge
          _card(
            decoration: AppDecorations.detailHero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.footerActiveBg,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        width: 1.5),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Valoraciones', style: t.headlineSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('Ayuda a mejorar nuestro servicio en un minuto.',
                          style: muted),
                      const SizedBox(height: AppSpacing.sm),
                      const StatusBadge('QR oficial',
                          tone: BadgeTone.brand,
                          icon: Icons.verified_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // QR destacado
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Escanea el QR y deja tu valoración',
                    textAlign: TextAlign.center, style: t.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text('Usa la cámara del móvil o cualquier lector de QR.',
                    textAlign: TextAlign.center, style: muted),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.brLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Image.asset(
                    'assets/images/qr_valoracion.jpg',
                    width: 280,
                    height: 280,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_rounded,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Gracias por compartir tu experiencia.',
                        style: muted),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Pasos numerados
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Cómo funciona?', style: t.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _step(context, 1, 'Abre la cámara del móvil y enfoca el QR.'),
                const SizedBox(height: AppSpacing.md),
                _step(context, 2,
                    'Completa la valoración en menos de un minuto.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go('/home'),
              style: AppDecorations.redButton,
              child: const Text('Volver al inicio'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, int n, String text) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.footerActiveBg,
            shape: BoxShape.circle,
          ),
          child: Text('$n',
              style: t.labelLarge?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(text,
              style:
                  t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _card({required Widget child, BoxDecoration? decoration}) {
    return Container(
      decoration: decoration ?? AppDecorations.whiteCard,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}
