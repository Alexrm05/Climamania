import 'package:flutter/material.dart';
import '../priority.dart';
import '../../theme/app_radius.dart';

/// Píldora de prioridad (Alta/Media/Baja/Sin prioridad) usando los colores
/// centralizados en [Prioridad].
class PriorityBadge extends StatelessWidget {
  final String label; // ya normalizado con Prioridad.parse(...)

  const PriorityBadge(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Prioridad.bg(label),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Prioridad.fg(label)),
      ),
    );
  }
}
