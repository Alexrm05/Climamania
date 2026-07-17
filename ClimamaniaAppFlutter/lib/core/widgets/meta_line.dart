import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Línea de metadatos con partes unidas por " · " (p. ej. "Equipo · Solicita ·
/// Fecha"). Ignora las partes vacías.
class MetaLine extends StatelessWidget {
  final List<String> parts;
  final int maxLines;

  const MetaLine(this.parts, {super.key, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    final text = parts.where((p) => p.trim().isNotEmpty).join(' · ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w500),
    );
  }
}
