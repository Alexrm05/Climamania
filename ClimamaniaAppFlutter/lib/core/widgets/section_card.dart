import 'package:flutter/material.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_spacing.dart';

/// Tarjeta de sección: título + contenido, sobre `whiteCard`. Unifica los
/// helpers duplicados `_section`/`_seccion` de las pantallas de detalle.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry margin;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.margin = const EdgeInsets.only(top: AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        width: double.infinity,
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
