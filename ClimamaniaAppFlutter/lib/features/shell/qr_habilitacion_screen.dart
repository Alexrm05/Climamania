import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// QR de habilitación como empresa instaladora, para enseñarlo cuando lo
/// piden en obra o en una inspección.
///
/// Se dibuja sobre blanco y lo más grande que cabe, con los píxeles sin
/// suavizar ([FilterQuality.none]): un QR ampliado con interpolación pierde
/// nitidez en los bordes y cuesta más leerlo.
class QrHabilitacionScreen extends StatelessWidget {
  const QrHabilitacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('QR Habilitación')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Habilitación empresa instaladora',
                    textAlign: TextAlign.center, style: t.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text('ClimaMania Sales Spain, S.L.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: AppRadius.brLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: LayoutBuilder(
                    builder: (ctx, c) {
                      final lado = c.maxWidth.clamp(180.0, 360.0);
                      return Image.asset(
                        'assets/images/qr_habilitacion_instaladora.png',
                        width: lado,
                        height: lado,
                        filterQuality: FilterQuality.none,
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Enséñalo para que lo escaneen.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
